/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import URLSessionInstrumentation
import XCTest
import SharedTestUtils

// Private URLSessionTask selector the instrumentation swizzles as its completion fallback.
private let setStateSelector = NSSelectorFromString("setState:")

/// Serves a fixed response body for one sentinel host, so tests can exercise the payload path.
/// Scoped to that host so registering it cannot affect any other request in the process.
final class PayloadStubURLProtocol: URLProtocol {
  static let host = "payload.stub"
  nonisolated(unsafe) static var body = Data("{\"message\":\"hello\"}".utf8)

  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == host
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let url = request.url ?? URL(string: "http://\(Self.host)/")!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                   headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

/// Declares a Content-Length far larger than the small body it actually sends, so tests can tell
/// a decision made from the declared length apart from one made from the bytes received.
final class LargeContentLengthStubURLProtocol: URLProtocol {
  static let host = "large-content-length.stub"
  static let body = Data("{\"message\":\"hello\"}".utf8)
  static let declaredContentLength = 1_000_000

  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == host
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let url = request.url ?? URL(string: "http://\(Self.host)/")!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                   headerFields: ["Content-Length": String(Self.declaredContentLength)])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

class URLSessionInstrumentationTests: XCTestCase {
  class Check {
    public var shouldRecordPayloadCalled: Bool = false
    public var shouldInstrumentCalled: Bool = false
    public var nameSpanCalled: Bool = false
    public var spanCustomizationCalled: Bool = false
    public var shouldInjectTracingHeadersCalled: Bool = false
    public var createdRequestCalled: Bool = false
    public var createdRequestCount: Int = 0
    public var receivedResponseCalled: Bool = false
    public var receivedErrorCalled: Bool = false
  }

  final class SessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, @unchecked Sendable {
    var semaphore: DispatchSemaphore

    init(semaphore: DispatchSemaphore) {
      self.semaphore = semaphore
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
      semaphore.signal()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      semaphore.signal()
    }
  }

  /// Implements didReceive, so the instrumentation's payload path runs for this session.
  final class DataReceivingDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, @unchecked Sendable {
    let semaphore: DispatchSemaphore

    init(semaphore: DispatchSemaphore) {
      self.semaphore = semaphore
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {}

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      semaphore.signal()
    }
  }

  final class CountingSessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, @unchecked Sendable {
    var callCount: Int = 0

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
      callCount += 1
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      callCount += 1
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
      callCount += 1
    }
  }

  final class PayloadSessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let semaphore: DispatchSemaphore
    private(set) var receivedData = Data()

    init(semaphore: DispatchSemaphore) {
      self.semaphore = semaphore
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
      completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
      receivedData.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
      semaphore.signal()
    }
  }

  /// A minimal delegate that only implements didFinishCollecting.
  /// This tests that delegate classes are discovered even when they only implement
  /// urlSession(_:task:didFinishCollecting:) and no other delegate methods.
  final class MinimalMetricsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    var didFinishCollectingCalled = false

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
      didFinishCollectingCalled = true
    }
  }

  nonisolated(unsafe) static var receivedResponseRequest: URLRequest?

  nonisolated(unsafe) static var createdSpanIds = [String]()

  nonisolated(unsafe) static var requestCopy: URLRequest!
  nonisolated(unsafe) static var responseCopy: HTTPURLResponse!
  nonisolated(unsafe) static var receivedDataOrFile: DataOrFile?

  nonisolated(unsafe) static var activeBaggage: Baggage!
  nonisolated(unsafe) static var customBaggage: Baggage!

  nonisolated(unsafe) static var config = URLSessionInstrumentationConfiguration(shouldRecordPayload: nil,
                                                             shouldInstrument: { req in
                                                               checker.shouldInstrumentCalled = true
                                                               if req.url?.path == "/dontinstrument" || req.url?.host == "dontinstrument.com" {
                                                                 return false
                                                               }
                                                               return true

                                                             },
                                                             nameSpan: { req in
                                                               checker.nameSpanCalled = true
                                                               if req.url?.host?.contains("defaultName") ?? false {
                                                                 return nil
                                                               }
                                                               return "new name"
                                                             },
                                                             spanCustomization: { req, spanBuilder in
                                                               checker.spanCustomizationCalled = true
                                                               if !(req.url?.host?.contains("defaultName") ?? false) {
                                                                 spanBuilder.setSpanKind(spanKind: .consumer)
                                                               }
                                                             },
                                                             shouldInjectTracingHeaders: { _ in
                                                               checker.shouldInjectTracingHeadersCalled = true
                                                               return true

                                                             },
                                                             createdRequest: { request, span in
                                                               requestCopy = request
                                                               checker.createdRequestCalled = true
                                                               checker.createdRequestCount += 1
                                                               createdSpanIds.append(span.context.spanId.hexString)
                                                             },
                                                             receivedResponse: { response, dataOrFile, _ in
                                                               responseCopy = response as? HTTPURLResponse
                                                               receivedDataOrFile = dataOrFile
                                                               checker.receivedResponseCalled = true
                                                             },
                                                             receivedResponseWithRequest: { _, _, _, request in
                                                               receivedResponseRequest = request
                                                             },
                                                             receivedError: { _, _, _, _ in
                                                               URLSessionInstrumentationTests.checker.receivedErrorCalled = true
                                                             },
                                                             baggageProvider: { _, _ in
                                                               customBaggage
                                                             })

  nonisolated(unsafe) static var checker = Check()
  nonisolated(unsafe) static var semaphore: DispatchSemaphore!
  var sessionDelegate: SessionDelegate!
  nonisolated(unsafe) static var instrumentation: URLSessionInstrumentation!

  static let server = HttpTestServer(url: URL(string: "http://localhost:33333"), config: nil)

  override class func setUp() {
    OpenTelemetry.registerPropagators(textPropagators: [W3CTraceContextPropagator()], baggagePropagator: W3CBaggagePropagator())
    OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderSdk())

    customBaggage = DefaultBaggageManager.instance.baggageBuilder()
      .put(key: EntryKey(name: "bar")!, value: EntryValue(string: "baz")!, metadata: nil)
      .build()

    activeBaggage = DefaultBaggageManager.instance.baggageBuilder()
      .put(key: EntryKey(name: "foo")!, value: EntryValue(string: "bar")!, metadata: nil)
      .build()

    OpenTelemetry.instance.contextProvider.setActiveBaggage(activeBaggage)

    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .default).async {
      do {
        try server.start(semaphore: sem)
      } catch {
        XCTFail()
        return
      }
    }
    sem.wait()
    instrumentation = URLSessionInstrumentation(configuration: config)
  }

  override class func tearDown() {
    server.stop()
    if customBaggage != nil {
      OpenTelemetry.instance.contextProvider.removeContextForBaggage(customBaggage)
    }
    customBaggage = nil
    OpenTelemetry.instance.contextProvider.removeContextForBaggage(activeBaggage)
  }

  override func setUp() {
    URLSessionInstrumentationTests.checker = Check()
    URLSessionInstrumentationTests.semaphore = DispatchSemaphore(value: 0)
    sessionDelegate = SessionDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
    URLSessionInstrumentationTests.requestCopy = nil
    URLSessionInstrumentationTests.responseCopy = nil
    URLSessionInstrumentationTests.receivedResponseRequest = nil
    URLSessionInstrumentationTests.receivedDataOrFile = nil
    URLSessionInstrumentationTests.createdSpanIds.removeAll()
    XCTAssertEqual(0, URLSessionInstrumentationTests.instrumentation.startedRequestSpans.count)
    URLSessionInstrumentationTests.instrumentation.configuration.semanticConvention = .old
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = nil
    URLSessionInstrumentationTests.instrumentation.configuration.responsePayloadRecordingMode = .all
  }

  override func tearDown() {
    URLSessionLogger.runningSpansQueue.sync {
      URLSessionLogger.runningSpans.removeAll()
    }
    XCTAssertEqual(0, URLSessionInstrumentationTests.instrumentation.startedRequestSpans.count)
  }

  /// HTTP semantic attributes and `traceparent` injection are only meaningful for http/https.
  /// Instrumenting other schemes produces a span describing an HTTP call that never happened,
  /// and injects tracing headers into a request no HTTP server will ever see.
  public func testNonHTTPSchemesAreNotInstrumented() {
    for url in ["file:///tmp/opentelemetry-swift.txt", "data:text/plain,hello"] {
      let request = URLRequest(url: URL(string: url)!)
      let taskId = "non-http-\(url)"

      URLSessionLogger.processAndLogRequest(request, sessionTaskId: taskId,
                                            instrumentation: URLSessionInstrumentationTests.instrumentation,
                                            shouldInjectHeaders: true)

      let started = URLSessionLogger.runningSpansQueue.sync { URLSessionLogger.runningSpans[taskId] }
      XCTAssertNil(started, "\(url) must not start an HTTP span")
    }

    XCTAssertFalse(URLSessionInstrumentationTests.checker.createdRequestCalled)
  }

  /// Swizzling is a process-wide effect, so it must only be applied once. A second instrumentation
  /// that swizzled again would capture the first one's implementation as its original and chain
  /// itself in front of it, reporting every request once per instance.
  public func testSecondInstrumentationDoesNotSwizzleAgain() {
    let selector = #selector(URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask)
    let implementationBefore = class_getMethodImplementation(URLSession.self, selector)

    let secondInstrumentation = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration())

    let implementationAfter = class_getMethodImplementation(URLSession.self, selector)
    XCTAssertEqual(implementationBefore, implementationAfter)

    withExtendedLifetime(secondInstrumentation) {}
  }

  public func testOverrideSpanName() {
    let request = URLRequest(url: URL(string: "http://google.com")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
    XCTAssertNotNil(URLSessionLogger.runningSpans["id"])
    if let span = URLSessionLogger.runningSpans["id"] {
      XCTAssertEqual("new name", span.name)
    }
  }

  public func testDefaultSpanName() {
    let request = URLRequest(url: URL(string: "http://defaultName.com")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
    XCTAssertNotNil(URLSessionLogger.runningSpans["id"])
    if let span = URLSessionLogger.runningSpans["id"] {
      XCTAssertEqual("HTTP GET", span.name)
    }
  }

  public func testDefaultSpanNameStableConventionIsMethodOnly() {
    URLSessionInstrumentationTests.instrumentation.configuration.semanticConvention = .stable

    var postRequest = URLRequest(url: URL(string: "http://defaultName.com/post")!)
    postRequest.httpMethod = "POST"
    let requests = [
      "get": URLRequest(url: URL(string: "http://defaultName.com")!),
      "post": postRequest
    ]

    for (id, request) in requests {
      URLSessionLogger.processAndLogRequest(request, sessionTaskId: id, instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)
    }

    XCTAssertEqual(2, URLSessionLogger.runningSpans.count)
    XCTAssertEqual("GET", URLSessionLogger.runningSpans["get"]?.name)
    XCTAssertEqual("POST", URLSessionLogger.runningSpans["post"]?.name)
  }

  public func testDefaultSpanNameHttpDupConventionKeepsLegacyName() {
    URLSessionInstrumentationTests.instrumentation.configuration.semanticConvention = .httpDup

    let request = URLRequest(url: URL(string: "http://defaultName.com")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertEqual("HTTP GET", URLSessionLogger.runningSpans["id"]?.name)
  }

  public func testOverrideSpanNameStableConvention() {
    URLSessionInstrumentationTests.instrumentation.configuration.semanticConvention = .stable

    let request = URLRequest(url: URL(string: "http://google.com")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
    XCTAssertEqual("new name", URLSessionLogger.runningSpans["id"]?.name)
  }

  public func testOverrideSpanCustomization() {
    let request = URLRequest(url: URL(string: "http://google.com")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
    XCTAssertNotNil(URLSessionLogger.runningSpans["id"])
    if let span = URLSessionLogger.runningSpans["id"] {
      XCTAssertEqual(SpanKind.consumer, span.kind)
    }
  }

  public func testDefaultSpanCustomization() {
    let request = URLRequest(url: URL(string: "http://defaultName.com")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
    XCTAssertNotNil(URLSessionLogger.runningSpans["id"])
    if let span = URLSessionLogger.runningSpans["id"] {
      XCTAssertEqual(SpanKind.client, span.kind)
    }
  }

  public func testConfigurationCallbacksCalledWhenSuccess() {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
      if let data {
        let string = String(decoding: data, as: UTF8.self)
        print(string)
      }
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()

    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
  }

  public func testCompletionHandlerHTTPErrorOnlyFiltersSuccessfulResponsePayload() {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.responsePayloadRecordingMode = .httpErrorsOnly
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)
    nonisolated(unsafe) var callerReceivedBody: Data?

    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
      callerReceivedBody = data
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()

    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(callerReceivedBody)
    XCTAssertNil(URLSessionInstrumentationTests.receivedDataOrFile)
  }

  public func testCompletionHandlerHTTPErrorOnlyIncludesHTTPErrorResponsePayload() throws {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.responsePayloadRecordingMode = .httpErrorsOnly
    let server = HttpTestServer(url: nil, config: HttpTestServerConfig())
    try server.start()
    defer { server.stop() }
    let request = URLRequest(url: URL(string: "http://127.0.0.1:\(server.serverPort)/forbidden")!)
    nonisolated(unsafe) var callerReceivedBody: Data?

    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
      callerReceivedBody = data
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()

    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertEqual(URLSessionInstrumentationTests.responseCopy.statusCode, 403)
    XCTAssertNotNil(callerReceivedBody)
    XCTAssertNotNil(URLSessionInstrumentationTests.receivedDataOrFile as? Data)
  }

  public func testDelegateHTTPErrorOnlyDoesNotBufferSuccessfulResponsePayload() throws {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.responsePayloadRecordingMode = .httpErrorsOnly
    let server = HttpTestServer(url: nil, config: HttpTestServerConfig())
    try server.start()
    defer { server.stop() }
    let expectedBody = Data("success response body".utf8)
    let delegate = PayloadSessionDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    let request = URLRequest(url: URL(string: "http://127.0.0.1:\(server.serverPort)/success-with-body")!)

    session.dataTask(with: request).resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(delegate.receivedData, expectedBody)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertEqual(URLSessionInstrumentationTests.responseCopy.statusCode, 200)
    XCTAssertNil(URLSessionInstrumentationTests.receivedDataOrFile)
  }

  public func testDelegateHTTPErrorOnlyBuffersHTTPErrorResponsePayload() throws {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.responsePayloadRecordingMode = .httpErrorsOnly
    let server = HttpTestServer(url: nil, config: HttpTestServerConfig())
    try server.start()
    defer { server.stop() }
    let expectedBody = Data("forbidden response body".utf8)
    let delegate = PayloadSessionDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    let request = URLRequest(url: URL(string: "http://127.0.0.1:\(server.serverPort)/forbidden-with-body")!)

    session.dataTask(with: request).resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(delegate.receivedData, expectedBody)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertEqual(URLSessionInstrumentationTests.responseCopy.statusCode, 403)
    XCTAssertEqual(URLSessionInstrumentationTests.receivedDataOrFile as? Data, expectedBody)
  }

  public func testDelegateDoesNotRecordPayloadLargerThanMaxRecordedPayloadSize() throws {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = 8
    defer { URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = nil }
    let server = HttpTestServer(url: nil, config: HttpTestServerConfig())
    try server.start()
    defer { server.stop() }
    let expectedBody = Data("success response body".utf8)
    let delegate = PayloadSessionDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    let request = URLRequest(url: URL(string: "http://127.0.0.1:\(server.serverPort)/success-with-body")!)

    session.dataTask(with: request).resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(delegate.receivedData, expectedBody)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNil(URLSessionInstrumentationTests.receivedDataOrFile)
  }

  public func testDelegateRecordsPayloadWithinMaxRecordedPayloadSize() throws {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = 1024
    defer { URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = nil }
    let server = HttpTestServer(url: nil, config: HttpTestServerConfig())
    try server.start()
    defer { server.stop() }
    let expectedBody = Data("success response body".utf8)
    let delegate = PayloadSessionDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    let request = URLRequest(url: URL(string: "http://127.0.0.1:\(server.serverPort)/success-with-body")!)

    session.dataTask(with: request).resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(delegate.receivedData, expectedBody)
    XCTAssertEqual(URLSessionInstrumentationTests.receivedDataOrFile as? Data, expectedBody)
  }

  public func testDelegateDoesNotRecordPayloadWhoseContentLengthExceedsMaxRecordedPayloadSize() {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = 1024
    defer { URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = nil }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [LargeContentLengthStubURLProtocol.self]
    let delegate = PayloadSessionDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    let url = URL(string: "http://\(LargeContentLengthStubURLProtocol.host)/body")!

    session.dataTask(with: URLRequest(url: url)).resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(delegate.receivedData, LargeContentLengthStubURLProtocol.body)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNil(URLSessionInstrumentationTests.receivedDataOrFile)
  }

  public func testCompletionHandlerAppliesMaxRecordedPayloadSizeLikeTheDelegatePath() {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = 8
    defer { URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = nil }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [PayloadStubURLProtocol.self]
    let session = URLSession(configuration: configuration)
    let url = URL(string: "http://\(PayloadStubURLProtocol.host)/body")!
    nonisolated(unsafe) var callerReceivedBody: Data?

    session.dataTask(with: URLRequest(url: url)) { data, _, _ in
      callerReceivedBody = data
      URLSessionInstrumentationTests.semaphore.signal()
    }.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(callerReceivedBody, PayloadStubURLProtocol.body)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNil(URLSessionInstrumentationTests.receivedDataOrFile)
  }

  public func testDownloadTaskFileURLIsNotAffectedByMaxRecordedPayloadSize() {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = 1
    defer { URLSessionInstrumentationTests.instrumentation.configuration.maxRecordedPayloadSize = nil }
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    URLSession.shared.downloadTask(with: request) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.receivedDataOrFile as? URL)
  }

  public func testConfigurationCallbacksCalledWhenForbidden() throws {
    #if os(watchOS)
      throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
    #endif

    let request = URLRequest(url: URL(string: "http://localhost:33333/forbidden")!)
    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
      if let data {
        let string = String(decoding: data, as: UTF8.self)
        print(string)
      }
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()

    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedErrorCalled)
  }

  public func testConfigurationCallbacksCalledWhenError() {
    let request = URLRequest(url: URL(string: "http://localhost:33333/error")!)
    let semaphore = DispatchSemaphore(value: 0)

    let task = URLSession.shared.dataTask(with: request) { _, _, _ in
      semaphore.signal()
    }
    task.resume()

    semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedErrorCalled)
  }

  public func testShouldInstrumentRequest() throws {
    let request1 = URLRequest(url: URL(string: "http://defaultName.com")!)
    let request2 = URLRequest(url: URL(string: "http://dontinstrument.com")!)

    _ = try XCTUnwrap(
      URLSessionLogger
        .processAndLogRequest(
          request1,
          sessionTaskId: "111",
          instrumentation: URLSessionInstrumentationTests.instrumentation,
          shouldInjectHeaders: true
        )
    )
    let processedRequest2 = URLSessionLogger.processAndLogRequest(request2, sessionTaskId: "222", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    // `processedRequest2` is expected to be nil, because its URL was marked as not to be instrumented.
    XCTAssertNil(processedRequest2)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)

    let span = try XCTUnwrap(URLSessionLogger.runningSpans["111"])
    XCTAssertEqual("HTTP GET", span.name)
  }

  public func testShouldInstrumentRequest_PropagateCombinedActiveAndCustomBaggages() throws {
    let request1 = URLRequest(url: URL(string: "http://defaultName.com")!)
    let request2 = URLRequest(url: URL(string: "http://dontinstrument.com")!)

    let processedRequest1 = try XCTUnwrap(URLSessionLogger.processAndLogRequest(request1, sessionTaskId: "111", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true))
    let processedRequest2 = URLSessionLogger.processAndLogRequest(request2, sessionTaskId: "222", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    // `processedRequest2` is expected to be nil, because its URL was marked as not to be instrumented.
    XCTAssertNil(processedRequest2)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)

    let processedHeaders1 = try XCTUnwrap(processedRequest1.allHTTPHeaderFields)

    // headers injected from `TextMapPropagator` implementation
    XCTAssertTrue(processedHeaders1.contains(where: { $0.key == W3CTraceContextPropagator.traceparent }))

    // headers injected from `TextMapBaggagePropagator` implementation
    let baggageHeaderValue = try XCTUnwrap(processedHeaders1[W3CBaggagePropagator.headerBaggage])

    // foo=bar propagated through active baggage defined in `setUp`
    XCTAssertTrue(baggageHeaderValue.contains("foo=bar"))

    // bar=baz propagated through custom baggage provided in `URLSessionInstrumentationConfiguration`
    XCTAssertTrue(baggageHeaderValue.contains("bar=baz"))

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)

    let span = try XCTUnwrap(URLSessionLogger.runningSpans["111"])
    XCTAssertEqual("HTTP GET", span.name)
  }

  public func testShouldInstrumentRequest_PropagateOnlyActiveBaggage() throws {
    Self.customBaggage = nil

    let request1 = URLRequest(url: URL(string: "http://defaultName.com")!)

    let processedRequest1 = try XCTUnwrap(URLSessionLogger.processAndLogRequest(request1, sessionTaskId: "111", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true))

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)

    let processedHeaders1 = try XCTUnwrap(processedRequest1.allHTTPHeaderFields)

    // headers injected from `TextMapPropagator` implementation
    XCTAssertTrue(processedHeaders1.contains(where: { $0.key == W3CTraceContextPropagator.traceparent }))

    // headers injected from `TextMapBaggagePropagator` implementation
    let baggageHeaderValue = try XCTUnwrap(processedHeaders1[W3CBaggagePropagator.headerBaggage])

    // bar=baz propagated through default baggage provided in `URLSessionInstrumentationConfiguration`
    XCTAssertEqual(baggageHeaderValue, "foo=bar")

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)

    let span = try XCTUnwrap(URLSessionLogger.runningSpans["111"])
    XCTAssertEqual("HTTP GET", span.name)
  }

  public func testDataTaskWithRequestBlock() {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    let task = URLSession.shared.dataTask(with: request) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }

    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(0, URLSessionInstrumentationTests.instrumentation.startedRequestSpans.count)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testDataTaskWithUrlBlock() {
    let url = URL(string: "http://localhost:33333/success")!

    let task = URLSession.shared.dataTask(with: url) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testDataTaskWithUrlBlock_doesNotCrashWhenResumed_whenDataTaskIsRunning() {
    let url = URL(string: "http://localhost:33333/success")!
    let dataTask = URLSession.shared.dataTask(with: url) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }

    dataTask.resume()
    Task.detached {
      dataTask.resume()
    }

    URLSessionInstrumentationTests.semaphore.wait()
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  /// Tests that resuming a task after suspend does not crash when using async/await methods.
  /// More info: https://github.com/open-telemetry/opentelemetry-swift/issues/937
  ///
  /// Bug scenario (before fix):
  /// 1. Create task in async context (state = .suspended, delegate = nil)
  /// 2. Resume (state => .running, detects async context and sets delegate)
  /// 3. Suspend (state => .suspended, delegate still set)
  /// 4. Resume again (state == .suspended, condition `!= .running` is true => tries to set delegate again and crashes)
  /// Reason => Task 4: "Cannot set task delegate after resumption"
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testDataTaskDoesNotCrashOnResumeAfterSuspend() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)
    let session = URLSession(configuration: .ephemeral)

    // I found this the easiest way to simulate the scenario
    await Task {
      let task = session.dataTask(with: request)

      XCTAssertEqual(task.state, .suspended)
      task.resume()

      // Give the task a moment to transition to running state
      try? await Task.sleep(nanoseconds: 50000000) // 0.05 seconds
      
      task.suspend()
      // With the old code (task.state != .running), this would try to set delegate again abd crash
      task.resume()
    }.value

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  /// The `traceparent` header is injected when the span is created. If a second span is created
  /// for the same task, it replaces the first in `runningSpans` and becomes the one reported,
  /// while the header already sent to the server still carries the first span's id. The reported
  /// span and the wire then disagree, silently breaking correlation.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testReportedSpanMatchesTraceparentSentOnTheWire() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)
    let session = URLSession(configuration: .ephemeral)

    _ = try? await session.data(for: request)

    XCTAssertEqual(URLSessionInstrumentationTests.checker.createdRequestCount, 1,
                   "one span per request; a second one orphans the first and diverges from the wire")

    let traceparent = URLSessionInstrumentationTests.requestCopy?
      .allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent]
    let spanIdOnWire = traceparent.map { String($0.split(separator: "-")[2]) }
    XCTAssertEqual(spanIdOnWire, URLSessionInstrumentationTests.createdSpanIds.last)
  }

  /// `resume()` can fire more than once for a single logical request (suspend/resume, superclass
  /// chaining, redirects). Each resume that starts another span replaces the first in
  /// `runningSpans`, leaving it unended and disagreeing with the header already on the wire.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testRepeatedResumeDoesNotStartASecondSpan() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)
    let session = URLSession(configuration: .ephemeral)

    await Task {
      let task = session.dataTask(with: request)
      task.resume()
      try? await Task.sleep(nanoseconds: 50_000_000)
      task.suspend()
      task.resume()
      try? await Task.sleep(nanoseconds: 50_000_000)
    }.value

    XCTAssertEqual(URLSessionInstrumentationTests.checker.createdRequestCount, 1,
                   "repeated resume must reuse the existing span, not start another")
  }

  public func testDownloadTaskWithUrlBlock() {
    let url = URL(string: "http://localhost:33333/success")!

    let task = URLSession.shared.downloadTask(with: url) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testUploadTaskWithUrlBlock() {
    let url = URL(string: "http://localhost:33333/success")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.uploadTask(
        with: request,
        from: "UploadData".data(using: .utf8)!
    )
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)

    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testUploadFileTaskWithUrlBlock() {
    let url = URL(string: "http://localhost:33333/success")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)

    let task = session.uploadTask(with: URLRequest(url: url), fromFile: url)
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)

    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testDownloadTaskWithRequestBlock() {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)

    let task = URLSession.shared.downloadTask(with: request) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testUploadTaskWithRequestBlock() {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)

    let task = URLSession.shared.uploadTask(with: request, from: Data()) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testDataTaskWithRequestDelegate() {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.dataTask(with: request)
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testDataTaskWithUrlDelegate() {
    let url = URL(string: "http://localhost:33333/success")!

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.dataTask(with: url)
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testDownloadTaskWithUrlDelegate() {
    let url = URL(string: "http://localhost:33333/success")!

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.downloadTask(with: url)
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testDownloadTaskWithRequestDelegate() {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.downloadTask(with: request)
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testUploadTaskWithRequestDelegate() {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.uploadTask(with: request, from: Data())
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testConfigurationCallbacksCalledWhenSuccessAsync() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    let (data, _) = try await URLSession.shared.data(for: request)
    let string = String(decoding: data, as: UTF8.self)
    print(string)

    // Note: These tests were passing incorrectly. The async/await methods
    // introduced in iOS 15/macOS 12 are NOT instrumented at all, which is what
    // testAsyncAwaitMethodsAreNotInstrumented demonstrates.
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testConfigurationCallbacksCalledWhenForbiddenAsync() async throws {
    #if os(watchOS)
      throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
    #endif
    let request = URLRequest(url: URL(string: "http://localhost:33333/forbidden")!)
    let (data, _) = try await URLSession.shared.data(for: request)
    let string = String(decoding: data, as: UTF8.self)
    print(string)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedErrorCalled)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testConfigurationCallbacksCalledWhenErrorAsync() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/error")!)

    do {
      _ = try await URLSession.shared.data(for: request)
    } catch {}

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedErrorCalled)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testDataTaskWithRequestBlockAsync() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    _ = try await URLSession.shared.data(for: request)

    XCTAssertEqual(0, URLSessionInstrumentationTests.instrumentation.startedRequestSpans.count)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testDataTaskWithUrlBlockAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!

    _ = try await URLSession.shared.data(from: url)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testDownloadTaskWithUrlBlockAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!

    _ = try await URLSession.shared.download(from: url)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testDownloadTaskWithRequestBlockAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)
    _ = try await URLSession.shared.download(for: request)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testUploadTaskWithRequestBlockAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)
    _ = try await URLSession.shared.upload(for: request, from: Data())

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func
    testDataTaskWithRequestDelegateAsync() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    let delegate = CountingSessionDelegate()

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: nil)
    let _ = try await session.data(for: request)

    XCTAssertEqual(1, delegate.callCount)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func
    testDataTaskWithTaskDelegateAsync() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    let delegate = CountingSessionDelegate()

    let session = URLSession(configuration: URLSessionConfiguration.default)
    let _ = try await session.data(for: request, delegate: delegate)

    XCTAssertEqual(1, delegate.callCount)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testDataTaskWithUrlDelegateAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    _ = try await session.data(from: url)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testDownloadTaskWithUrlDelegateAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!

    _ = try await URLSession.shared.download(from: url, delegate: sessionDelegate)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testDownloadTaskWithSessionDelegateAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    _ = try await session.download(for: request)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testDownloadTaskWithRequestDelegateAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)

    let session = URLSession(configuration: URLSessionConfiguration.default)
    _ = try await session.download(for: request, delegate: sessionDelegate)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testUploadTaskWithSessionDelegateAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)
    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    _ = try await session.upload(for: request, from: Data())

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  @available(macOS 10.15, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testUploadTaskWithRequestDelegateAsync() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)
    let session = URLSession(configuration: URLSessionConfiguration.default)
    _ = try await session.upload(for: request, from: Data(), delegate: sessionDelegate)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
  }

  public func testNonInstrumentedRequestCompletes() {
    let request = URLRequest(url: URL(string: "http://localhost:33333/dontinstrument")!)
    let expectation = expectation(description: "Non-instrumented request completes")

    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.dataTask(with: request) { _, response, error in
      XCTAssertNil(error, "Non-instrumented request should not error")
      XCTAssertNotNil(response, "Non-instrumented request should receive response")
      if let httpResponse = response as? HTTPURLResponse {
        XCTAssertEqual(httpResponse.statusCode, 200, "Non-instrumented request should receive 200 OK")
      } else {
        XCTFail("Response should be HTTPURLResponse")
      }

      // Verify that no instrumentation was added
      XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled, "shouldInstrument should be called")
      XCTAssertFalse(URLSessionInstrumentationTests.checker.nameSpanCalled, "nameSpan should not be called")
      XCTAssertFalse(URLSessionInstrumentationTests.checker.spanCustomizationCalled, "spanCustomization should not be called")
      XCTAssertFalse(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled, "shouldInjectTracingHeaders should not be called")
      XCTAssertFalse(URLSessionInstrumentationTests.checker.createdRequestCalled, "createdRequest should not be called")
      XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedResponseCalled, "receivedResponse should not be called")

      // Verify the request wasn't modified
      XCTAssertNil(URLSessionInstrumentationTests.requestCopy, "Request should not have been copied/modified")
      XCTAssertEqual(0, URLSessionLogger.runningSpans.count, "No spans should be created for non-instrumented requests")

      expectation.fulfill()
    }
    task.resume()

    wait(for: [expectation], timeout: 5)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testNonInstrumentedRequestCompletesAsync() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/dontinstrument")!)

    let configuration = URLSessionConfiguration.default
    let session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)

    let (_, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      XCTFail("Response should be HTTPURLResponse")
      return
    }

    XCTAssertEqual(httpResponse.statusCode, 200, "Non-instrumented request should receive 200 OK")

    // Verify that no instrumentation was added
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled, "shouldInstrument should be called")
    XCTAssertFalse(URLSessionInstrumentationTests.checker.nameSpanCalled, "nameSpan should not be called")
    XCTAssertFalse(URLSessionInstrumentationTests.checker.spanCustomizationCalled, "spanCustomization should not be called")
    XCTAssertFalse(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled, "shouldInjectTracingHeaders should not be called")
    XCTAssertFalse(URLSessionInstrumentationTests.checker.createdRequestCalled, "createdRequest should not be called")
    XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedResponseCalled, "receivedResponse should not be called")

    // Verify the request wasn't modified
    XCTAssertNil(URLSessionInstrumentationTests.requestCopy, "Request should not have been copied/modified")
    XCTAssertEqual(0, URLSessionLogger.runningSpans.count, "No spans should be created for non-instrumented requests")
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testNonInstrumentedRequestCompletesAsync_NonTaskContext() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/dontinstrument")!)

    let configuration = URLSessionConfiguration.default
    let session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)

    // Run in a detached task to ensure we're not in the main Task context
    let task = Task.detached {
      // Ensure we're not in a Task context by running on a background thread
      await Task.yield()
      let (_, response) = try await session.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        XCTFail("Response should be HTTPURLResponse")
        return
      }

      XCTAssertEqual(httpResponse.statusCode, 200, "Non-instrumented request should receive 200 OK")
    }

    try await task.value
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testNonInstrumentedRequestCompletesAsync_ExplicitTaskContext() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/dontinstrument")!)

    let configuration = URLSessionConfiguration.default
    let session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)

    // Run in an explicit task to ensure we're in a Task context
    let task = Task {
      let (_, response) = try await session.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        XCTFail("Response should be HTTPURLResponse")
        return
      }

      XCTAssertEqual(httpResponse.statusCode, 200, "Non-instrumented request should receive 200 OK")
    }

    try await task.value
  }
  
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testAsyncAwaitMethodsDoNotCompleteSpans() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)
    
    // Test data(for:) method - the new async/await API introduced in iOS 15
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      XCTFail("Response should be HTTPURLResponse")
      return
    }
    
    XCTAssertEqual(httpResponse.statusCode, 200, "Request should succeed")
    XCTAssertNotNil(data, "Should receive data")

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled, "receivedResponse should be called")
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent], "Headers are injected")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled, "shouldInstrument should be called")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled, "createdRequest should be called")
  }
  
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testAsyncAwaitDownloadMethodsAreNotInstrumented() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    
    // Test download(from:) method
    let (fileURL, response) = try await URLSession.shared.download(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      XCTFail("Response should be HTTPURLResponse")
      return
    }
    
    XCTAssertEqual(httpResponse.statusCode, 200, "Request should succeed")
    XCTAssertNotNil(fileURL, "Should receive file URL")
    
    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled, "shouldInstrument should be called")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled, "createdRequest should be called")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled, "receivedResponse should be called")
    
    // Clean up downloaded file
    try? FileManager.default.removeItem(at: fileURL)
  }
  
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testAsyncAwaitUploadMethodsAreNotInstrumented() async throws {
    let url = URL(string: "http://localhost:33333/success")!
    let request = URLRequest(url: url)

    // Test upload(for:from:) method
    let (data, response) = try await URLSession.shared.upload(for: request, from: Data())

    guard let httpResponse = response as? HTTPURLResponse else {
      XCTFail("Response should be HTTPURLResponse")
      return
    }

    XCTAssertEqual(httpResponse.statusCode, 200, "Request should succeed")
    XCTAssertNotNil(data, "Should receive response data")

    XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled, "shouldInstrument should be called")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled, "createdRequest should be called")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled, "receivedResponse should be called")
  }

  /// Tests that delegate classes are discovered and swizzled even when they only implement
  /// urlSession(_:task:didFinishCollecting:) and no other delegate methods.
  /// This is a regression test for a bug where the selector for didFinishCollecting was missing
  /// from the delegate discovery mechanism.
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
  public func testDelegateWithOnlyDidFinishCollectingIsDiscovered() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

    let delegate = MinimalMetricsDelegate()
    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: nil)

    _ = try await session.data(for: request)

    // Verify the user's delegate was called (proves swizzling forwarded the call)
    XCTAssertTrue(delegate.didFinishCollectingCalled, "Delegate should receive metrics callback")

    // Verify instrumentation worked (span was created and completed)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled, "Instrumentation should capture the request")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled, "Instrumentation should capture the response")
  }

  public func testOldSemanticConvention() {
    URLSessionInstrumentationTests.instrumentation.configuration.semanticConvention = .old

    let request = URLRequest(url: URL(string: "http://example.com:8080/path")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "test-old", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
    guard let span = URLSessionLogger.runningSpans["test-old"] as? SpanSdk else {
      XCTFail("Span should be SpanSdk")
      return
    }

    let attributes = span.toSpanData().attributes

    // Verify old semantic convention attributes are present
    XCTAssertEqual(attributes["http.method"]?.description, "GET")
    XCTAssertEqual(attributes["http.target"]?.description, "/path")
    XCTAssertEqual(attributes["net.peer.name"]?.description, "example.com")
    XCTAssertEqual(attributes["net.peer.port"]?.description, "8080")
    XCTAssertEqual(attributes["http.scheme"]?.description, "http")

    // Verify stable semantic convention attributes are NOT present
    XCTAssertNil(attributes["http.request.method"])
    XCTAssertNil(attributes["url.full"])
    XCTAssertNil(attributes["url.path"])
    XCTAssertNil(attributes["server.address"])
    XCTAssertNil(attributes["server.port"])
    XCTAssertNil(attributes["url.scheme"])
  }

  public func testStableSemanticConvention() {
    URLSessionInstrumentationTests.instrumentation.configuration.semanticConvention = .stable

    let request = URLRequest(url: URL(string: "http://example.com:8080/path")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "test-stable", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
    guard let span = URLSessionLogger.runningSpans["test-stable"] as? SpanSdk else {
      XCTFail("Span should be SpanSdk")
      return
    }

    let attributes = span.toSpanData().attributes

    // Verify stable semantic convention attributes are present
    XCTAssertEqual(attributes["http.request.method"]?.description, "GET")
    XCTAssertEqual(attributes["url.path"]?.description, "/path")
    XCTAssertEqual(attributes["server.address"]?.description, "example.com")
    XCTAssertEqual(attributes["server.port"]?.description, "8080")
    XCTAssertEqual(attributes["url.scheme"]?.description, "http")

    // Verify old semantic convention attributes are NOT present
    XCTAssertNil(attributes["http.method"])
    XCTAssertNil(attributes["http.url"])
    XCTAssertNil(attributes["http.target"])
    XCTAssertNil(attributes["net.peer.name"])
    XCTAssertNil(attributes["net.peer.port"])
    XCTAssertNil(attributes["http.scheme"])
  }

  public func testHttpDupSemanticConvention() {
    URLSessionInstrumentationTests.instrumentation.configuration.semanticConvention = .httpDup

    let request = URLRequest(url: URL(string: "http://example.com:8080/path")!)

    URLSessionLogger.processAndLogRequest(request, sessionTaskId: "test-dup", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

    XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
    guard let span = URLSessionLogger.runningSpans["test-dup"] as? SpanSdk else {
      XCTFail("Span should be SpanSdk")
      return
    }

    let attributes = span.toSpanData().attributes

    // Verify BOTH old and stable semantic convention attributes are present
    // Old attributes
    XCTAssertEqual(attributes["http.method"]?.description, "GET")
    XCTAssertEqual(attributes["http.target"]?.description, "/path")
    XCTAssertEqual(attributes["net.peer.name"]?.description, "example.com")
    XCTAssertEqual(attributes["net.peer.port"]?.description, "8080")
    XCTAssertEqual(attributes["http.scheme"]?.description, "http")

    // Stable attributes
    XCTAssertEqual(attributes["http.request.method"]?.description, "GET")
    XCTAssertEqual(attributes["url.path"]?.description, "/path")
    XCTAssertEqual(attributes["server.address"]?.description, "example.com")
    XCTAssertEqual(attributes["server.port"]?.description, "8080")
    XCTAssertEqual(attributes["url.scheme"]?.description, "http")
  }

  // MARK: - Background session tests
  @available(macOS 10.15, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testBackgroundSession_ShouldNotCrashWhenAssigningDelegate() async throws {
    let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)
    
    // Background sessions require a delegate to be set when creating the session.
    // However, for this test, we set to nil so it tries to do it on resume (where the crash happens)
    let session = URLSession(
      configuration: URLSessionConfiguration.background(
        withIdentifier: UUID().uuidString
      ),
      delegate: nil,
      delegateQueue: .main
    )
    
    // Background sessions cannot use async/await or completion handlers
    // Must use dataTask(with:) and call resume()
    let task = session.dataTask(with: request)
    task.resume()
    
    // The test passes if tasks completes without crashing.
    wait { task.state == .completed }
  }

  /// receivedResponse is given the request the response belongs to, so a consumer can correlate the
  /// two without keeping its own table of in-flight requests keyed by task.
  public func testReceivedResponseIsGivenTheOriginatingRequest() {
    let url = URL(string: "http://localhost:33333/success")!
    let reported = expectReceivedResponseWithRequest()
    let session = URLSession(configuration: .default, delegate: sessionDelegate, delegateQueue: nil)
    let task = session.dataTask(with: URLRequest(url: url))
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()
    wait(for: [reported], timeout: 5)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertEqual(URLSessionInstrumentationTests.receivedResponseRequest?.url, url)
  }

  /// A task with no delegate and no completion handler is reported by the setState fallback, which
  /// must still be able to hand receivedResponseWithRequest the request.
  public func testReceivedResponseIsGivenTheRequestWithoutADelegateOrCompletionHandler() {
    let url = URL(string: "http://localhost:33333/success")!
    let reported = expectReceivedResponseWithRequest()
    let session = URLSession(configuration: .ephemeral)
    defer { session.finishTasksAndInvalidate() }
    session.dataTask(with: URLRequest(url: url)).resume()
    wait(for: [reported], timeout: 5)

    XCTAssertEqual(URLSessionInstrumentationTests.receivedResponseRequest?.url, url)
  }

  /// The response can be reported from a URLSession thread after the delegate has already been
  /// called, so tests wait on this rather than on the delegate to read what the callback recorded.
  private func expectReceivedResponseWithRequest() -> XCTestExpectation {
    let reported = expectation(description: "receivedResponseWithRequest is called")
    let instrumentation = URLSessionInstrumentationTests.instrumentation!
    let original = instrumentation.configuration.receivedResponseWithRequest
    instrumentation.configuration.receivedResponseWithRequest = { response, dataOrFile, span, request in
      original?(response, dataOrFile, span, request)
      reported.fulfill()
    }
    addTeardownBlock { instrumentation.configuration.receivedResponseWithRequest = original }
    return reported
  }

  /// The per-request payload callback is asked with the request it is deciding about, so an app can
  /// record payloads for some endpoints without turning it on for the whole session.
  public func testPerRequestPayloadCallbackIsAskedWithTheRequest() {
    URLProtocol.registerClass(PayloadStubURLProtocol.self)
    defer { URLProtocol.unregisterClass(PayloadStubURLProtocol.self) }

    let url = URL(string: "http://\(PayloadStubURLProtocol.host)/body")!
    nonisolated(unsafe) var askedFor = [URL]()
    let askedLock = NSLock()

    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayloadForRequest = { request in
      if let requestURL = request.url {
        askedLock.withLock { askedFor.append(requestURL) }
      }
      return true
    }
    defer {
      URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayloadForRequest = nil
    }

    let delegate = DataReceivingDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [PayloadStubURLProtocol.self]
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    let task = session.dataTask(with: URLRequest(url: url))
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    let observed = askedLock.withLock { askedFor }
    XCTAssertEqual(observed.first, url, "the callback should be asked about the request being sent")
  }

  /// `shouldRecordPayload` defaults to off and the session-delegate path honours it, but the
  /// completion handler path handed the response body to `receivedResponse` regardless. An app that
  /// never opted in still received response bodies in its telemetry callback.
  public func testCompletionHandlerHonoursShouldRecordPayload() {
    let url = URL(string: "http://localhost:33333/success")!
    nonisolated(unsafe) var callerReceivedBody: Data?

    let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, _ in
      callerReceivedBody = data
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertNotNil(callerReceivedBody, "the caller's completion handler must still get its data")
    XCTAssertNil(URLSessionInstrumentationTests.receivedDataOrFile,
                 "payload recording is disabled, so no body should reach receivedResponse")
  }


  /// The completion handler paths go through the same gate as the session delegate path, so the
  /// per-request callback decides for them too rather than being silently ignored.
  public func testCompletionHandlerHonoursPerRequestPayloadCallback() {
    let url = URL(string: "http://\(PayloadStubURLProtocol.host)/body")!
    nonisolated(unsafe) var askedFor = [URL]()
    let askedLock = NSLock()

    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayloadForRequest = { request in
      if let requestURL = request.url {
        askedLock.withLock { askedFor.append(requestURL) }
      }
      return true
    }
    defer {
      URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayloadForRequest = nil
    }

    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [PayloadStubURLProtocol.self]
    let session = URLSession(configuration: configuration)

    let task = session.dataTask(with: URLRequest(url: url)) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(askedLock.withLock { askedFor }.first, url,
                   "the per-request callback should decide for completion handler tasks too")
    XCTAssertEqual((URLSessionInstrumentationTests.receivedDataOrFile as? Data),
                   PayloadStubURLProtocol.body,
                   "recording was allowed for this request, so the body should reach receivedResponse")
  }

  /// A task with no session delegate and no completion handler has its span started by the factory
  /// swizzle, and before the setState fallback there was nothing left to end it: the span stayed in
  /// runningSpans for the lifetime of the process.
  public func testSpanIsEndedWithoutADelegateOrCompletionHandler() {
    let session = URLSession(configuration: .ephemeral)
    let task = session.dataTask(with: URLRequest(url: URL(string: "http://localhost:33333/success")!))
    task.resume()
    wait(timeout: 5) { task.state == .completed }

    let leaked = URLSessionInstrumentationTests.instrumentation.startedRequestSpans
    XCTAssertTrue(leaked.isEmpty, "nothing ended the span: \(leaked.count) still running")
  }

  /// A session delegate implementing none of the instrumented selectors is never swizzled, so
  /// nothing reports task completion for that session. The span started at resume is then never
  /// ended and stays in `runningSpans` for the lifetime of the process.
  final class OpaqueSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {}
  }

  public func testSpanIsEndedWhenSessionDelegateImplementsNoInstrumentedSelector() {
    let session = URLSession(configuration: .ephemeral,
                             delegate: OpaqueSessionDelegate(),
                             delegateQueue: nil)
    let task = session.dataTask(with: URLRequest(url: URL(string: "http://localhost:33333/success")!))
    task.resume()

    wait { task.state == .completed }

    let leaked = URLSessionInstrumentationTests.instrumentation.startedRequestSpans
    XCTAssertTrue(leaked.isEmpty,
                  "the span started at resume was never ended: \(leaked.count) still running")
  }

  final class HoldInDidReceiveDataDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let inDidReceiveData = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let completed = DispatchSemaphore(value: 0)

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
      inDidReceiveData.signal()
      release.wait()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didBecome downloadTask: URLSessionDownloadTask) {}

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      guard !(task is SetStateInterleavingTask) else { return }
      completed.signal()
    }
  }

  /// The delegate completion path reads `response` right after taking the task's recorded state, so
  /// the first read runs the setState: fallback inside that path's window.
  final class SetStateInterleavingTask: URLSessionDownloadTask, @unchecked Sendable {
    private var stubResponse: URLResponse?
    private var interleaved = false

    // URLSessionTask.init() is deprecated for real tasks; this fake is never resumed.
    static func make(response: URLResponse) -> SetStateInterleavingTask? {
      let task = (self as NSObject.Type).init() as? SetStateInterleavingTask
      task?.stubResponse = response
      return task
    }

    override var error: Error? { nil }

    override var response: URLResponse? {
      if !interleaved {
        interleaved = true
        typealias SetStateIMP = @convention(c) (AnyObject, Selector, URLSessionTask.State) -> Void
        unsafeBitCast(method(for: setStateSelector), to: SetStateIMP.self)(self, setStateSelector, .completed)
      }
      return stubResponse
    }
  }

  /// The setState fallback and the delegate callbacks report the same task from different queues.
  /// Whichever one ends the span must end it with the payload the delegate path recorded.
  public func testPayloadIsKeptWhenSetStateFallbackRunsInsideDelegateCompletion() throws {
    URLSessionInstrumentationTests.instrumentation.configuration.shouldRecordPayload = { _ in true }
    let server = HttpTestServer(url: nil, config: HttpTestServerConfig())
    try server.start()
    defer { server.stop() }
    let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(server.serverPort)/success-with-body"))
    let delegate = HoldInDidReceiveDataDelegate()
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    let task = session.dataTask(with: URLRequest(url: url))
    task.resume()
    XCTAssertEqual(delegate.inDidReceiveData.wait(timeout: .now() + 5), .success)

    let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    let interleavingTask = try XCTUnwrap(SetStateInterleavingTask.make(response: response))
    // Called through the protocol so the calls go through the ObjC runtime and reach the swizzles.
    let dispatched: URLSessionDataDelegate = delegate
    dispatched.urlSession?(session, dataTask: task, didBecome: interleavingTask)
    dispatched.urlSession?(session, task: interleavingTask, didCompleteWithError: nil)

    delegate.release.signal()
    XCTAssertEqual(delegate.completed.wait(timeout: .now() + 5), .success)

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertEqual(URLSessionInstrumentationTests.responseCopy?.statusCode, 200)
    XCTAssertEqual(URLSessionInstrumentationTests.receivedDataOrFile as? Data, Data("success response body".utf8),
                   "the span was ended without the payload the delegate path had recorded")
  }

  /// A WebSocket opening handshake is an HTTP request, so it stays instrumented.
  ///
  /// The two overloads differ: `webSocketTask(with: URL)` is rewritten by Foundation to `http`,
  /// while `webSocketTask(with: URLRequest)` keeps `ws` on both `originalRequest` and
  /// `currentRequest`. The scheme filter has to allow `ws`/`wss` for the second to work, so both are
  /// covered here.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testWebSocketTaskWithURLRequestIsStillInstrumented() async {
    let session = URLSession(configuration: .ephemeral)
    let task = session.webSocketTask(with: URLRequest(url: URL(string: "ws://localhost:33333/socket")!))

    // Resumed from an async context; the non-async path is covered by
    // testWebSocketTaskResumedOutsideSwiftConcurrencyIsInstrumented.
    await Task { task.resume() }.value
    wait { URLSessionInstrumentationTests.checker.createdRequestCalled }
    task.cancel()

    XCTAssertEqual(URLSessionInstrumentationTests.requestCopy?.url?.scheme, "ws",
                   "this overload keeps the ws scheme, so the filter has to allow it")
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?
      .allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent],
                    "the handshake should still carry traceparent")
  }

  /// A task that no factory swizzle instruments, such as a WebSocket handshake, can only get its
  /// span from resume. Resuming it from ordinary, non-async code must start that span too, and the
  /// span must be ended once the task completes.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testWebSocketTaskResumedOutsideSwiftConcurrencyIsInstrumented() {
    let session = URLSession(configuration: .ephemeral)
    assertResumeOutsideSwiftConcurrencyStartsAndEndsSpan(in: session)
  }

  /// Same as above for a session that has a delegate, which the async-context heuristic on
  /// iOS 15/macOS 12 never treats as async.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testWebSocketTaskOnDelegateSessionResumedOutsideSwiftConcurrencyIsInstrumented() {
    let session = URLSession(configuration: .ephemeral, delegate: sessionDelegate, delegateQueue: nil)
    assertResumeOutsideSwiftConcurrencyStartsAndEndsSpan(in: session)
  }

  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  private func assertResumeOutsideSwiftConcurrencyStartsAndEndsSpan(in session: URLSession,
                                                                    file: StaticString = #filePath,
                                                                    line: UInt = #line) {
    let task = session.webSocketTask(with: URLRequest(url: URL(string: "ws://localhost:33333/socket")!))

    task.resume()
    wait { URLSessionInstrumentationTests.checker.createdRequestCalled }

    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled,
                  "a task resumed outside a Swift Task should still start a span", file: file, line: line)
    XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?
      .allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent],
                    "the handshake should carry traceparent", file: file, line: line)

    task.cancel()
    wait { URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty }

    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedErrorCalled,
                  "the cancelled task's completion should be reported", file: file, line: line)
    XCTAssertTrue(URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty,
                  "the span started at resume should be ended", file: file, line: line)
  }

  /// A completion-handler task reports its own completion, so the setState fallback skips it. A
  /// later resume of the finished task must not start a span that nothing will ever end.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testResumingCompletedDataTaskWithCompletionHandlerStartsNoSpan() {
    let url = URL(string: "http://localhost:33333/success")!
    let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    assertResumingCompletedTaskStartsNoSpan(task)
  }

  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testResumingCompletedUploadTaskWithCompletionHandlerStartsNoSpan() {
    var request = URLRequest(url: URL(string: "http://localhost:33333/success")!)
    request.httpMethod = "POST"
    let task = URLSession.shared.uploadTask(with: request, from: Data("body".utf8)) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    assertResumingCompletedTaskStartsNoSpan(task)
  }

  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  private func assertResumingCompletedTaskStartsNoSpan(_ task: URLSessionTask,
                                                       file: StaticString = #filePath,
                                                       line: UInt = #line) {
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()
    wait { task.state == .completed && URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty }
    let requestsBeforeResume = URLSessionInstrumentationTests.checker.createdRequestCount

    task.resume()

    XCTAssertEqual(URLSessionInstrumentationTests.checker.createdRequestCount, requestsBeforeResume,
                   "resuming a completed task should not start another span", file: file, line: line)
    XCTAssertTrue(URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty,
                  "no span should be left running after resuming a completed task", file: file, line: line)
  }

  /// The completion handler can run before the `setState:` swizzle has finished, so a resume from
  /// inside the handler must not start a span either.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testResumingTaskFromItsOwnCompletionHandlerStartsNoSpan() {
    let url = URL(string: "http://localhost:33333/success")!
    nonisolated(unsafe) var task: URLSessionTask?
    nonisolated(unsafe) var requestsBeforeResume = 0
    task = URLSession.shared.dataTask(with: URLRequest(url: url)) { _, _, _ in
      requestsBeforeResume = URLSessionInstrumentationTests.checker.createdRequestCount
      task?.resume()
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task?.resume()
    URLSessionInstrumentationTests.semaphore.wait()

    XCTAssertEqual(URLSessionInstrumentationTests.checker.createdRequestCount, requestsBeforeResume,
                   "resuming a task from its completion handler should not start another span")
    wait { URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty }
    XCTAssertTrue(URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty,
                  "no span should be left running after resuming from the completion handler")
  }

  /// Checking for an existing span and starting one must be atomic. Two threads resuming the same
  /// task can otherwise both see no span, both start one, and the second replaces the first in
  /// `runningSpans` — the orphaned span and wire mismatch this guard exists to prevent.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public func testConcurrentResumesStartOneSpanOnly() async {
    nonisolated(unsafe) var count = 0
    let countLock = NSLock()
    let original = URLSessionInstrumentationTests.instrumentation.configuration.createdRequest
    URLSessionInstrumentationTests.instrumentation.configuration.createdRequest = { _, _ in
      countLock.withLock { count += 1 }
    }
    defer { URLSessionInstrumentationTests.instrumentation.configuration.createdRequest = original }

    // A webSocketTask is not instrumented when created, so resume is the only thing that can start
    // its span, which is the window two threads can race through.
    let session = URLSession(configuration: .ephemeral)
    let task = session.webSocketTask(with: URL(string: "ws://localhost:33333/socket")!)

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 2 {
        group.addTask { task.resume() }
      }
    }
    try? await Task.sleep(nanoseconds: 300_000_000)
    task.cancel()

    XCTAssertEqual(count, 1, "two concurrent resumes must start a single span")
  }


  /// `ignoredClassPrefixes` was stored but never read, so setting it excluded nothing.
  ///
  /// The scan runs once per process, during the first initializer, so it cannot be re-run from a
  /// test with a different configuration. This exercises the exclusion decision itself, which is
  /// what the scan consults for every class it considers.
  public func testIgnoredClassPrefixesExcludeMatchingClasses() {
    let cls: AnyClass = SessionDelegate.self
    let name = NSStringFromClass(cls)
    XCTAssertFalse(name.isEmpty)

    XCTAssertFalse(URLSessionInstrumentation.isExcludedFromInstrumentation(cls, ignoredPrefixes: nil),
                   "nothing is excluded when no prefixes are given")
    XCTAssertFalse(URLSessionInstrumentation.isExcludedFromInstrumentation(cls, ignoredPrefixes: []),
                   "an empty list excludes nothing")
    XCTAssertFalse(URLSessionInstrumentation.isExcludedFromInstrumentation(cls, ignoredPrefixes: ["NotAPrefixOfAnything"]),
                   "a prefix that does not match leaves the class instrumented")
    XCTAssertFalse(URLSessionInstrumentation.isExcludedFromInstrumentation(cls, ignoredPrefixes: [""]),
                   "an empty prefix must not exclude everything")

    XCTAssertTrue(URLSessionInstrumentation.isExcludedFromInstrumentation(cls, ignoredPrefixes: [String(name.prefix(6))]),
                  "a matching prefix excludes the class")
    XCTAssertTrue(URLSessionInstrumentation.isExcludedFromInstrumentation(cls, ignoredPrefixes: ["NotAMatch", String(name.prefix(6))]),
                  "any one of the prefixes matching is enough")
  }



  /// Covers the selection step the search performs, so that removing the exclusion check from it
  /// fails here rather than only changing behaviour at runtime.
  public func testScanOmitsClassesMatchingIgnoredPrefixes() {
    let cls: AnyClass = SessionDelegate.self
    let name = NSStringFromClass(cls)
    let selectors = [#selector(URLSessionDataDelegate.urlSession(_:task:didCompleteWithError:))]

    let selected = URLSessionInstrumentation.delegateClassesToInject(
      from: [cls], matching: selectors, ignoredPrefixes: nil)
    XCTAssertTrue(selected.contains { $0 === cls },
                  "the class implements the selector, so the search should select it")

    let withIgnoredPrefix = URLSessionInstrumentation.delegateClassesToInject(
      from: [cls], matching: selectors, ignoredPrefixes: [String(name.prefix(6))])
    XCTAssertTrue(withIgnoredPrefix.isEmpty,
                  "a class matching an ignored prefix must not be selected")

    let withUnrelatedPrefix = URLSessionInstrumentation.delegateClassesToInject(
      from: [cls], matching: selectors, ignoredPrefixes: ["NotAPrefixOfAnything"])
    XCTAssertTrue(withUnrelatedPrefix.contains { $0 === cls },
                  "a prefix that does not match must leave the class selected")
  }

  /// Session delegates that implement none of the scanned selectors, so the startup scan never
  /// selects them and only resuming a task could instrument them. One per test, so that one test
  /// instrumenting its class cannot hide the result of the other.
  final class IgnoredPrefixSuccessDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {}
  }

  final class IgnoredPrefixErrorDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {}
  }

  public func testResumeDoesNotInstrumentIgnoredDelegateOnSuccess() {
    assertResumeLeavesIgnoredDelegateUninstrumented(delegate: IgnoredPrefixSuccessDelegate(),
                                                    url: "http://localhost:33333/success")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedErrorCalled)
  }

  public func testResumeDoesNotInstrumentIgnoredDelegateOnError() {
    assertResumeLeavesIgnoredDelegateUninstrumented(delegate: IgnoredPrefixErrorDelegate(),
                                                    url: "http://localhost:33333/error")
    XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedErrorCalled)
  }

  /// Resuming a task instruments its session delegate lazily. A delegate matching
  /// `ignoredClassPrefixes` must be left alone on that path too, and the request's span must still
  /// end, since the span is started before the delegate is considered.
  private func assertResumeLeavesIgnoredDelegateUninstrumented(delegate: URLSessionDelegate & NSObject,
                                                               url: String,
                                                               file: StaticString = #filePath,
                                                               line: UInt = #line) {
    let cls: AnyClass = type(of: delegate)
    let didComplete = #selector(URLSessionDataDelegate.urlSession(_:task:didCompleteWithError:))
    XCTAssertNil(class_getInstanceMethod(cls, didComplete),
                 "precondition: the delegate starts without the method instrumenting it would add",
                 file: file, line: line)

    // The callbacks run on a URLSession thread, after the span has been removed from the running
    // spans. Waiting on this expectation orders their writes before the reads below.
    let reported = expectation(description: "the task's completion is reported")

    let instrumentation = URLSessionInstrumentationTests.instrumentation!
    let original = instrumentation.configuration
    instrumentation.configuration = URLSessionInstrumentationConfiguration(
      createdRequest: { _, _ in URLSessionInstrumentationTests.checker.createdRequestCalled = true },
      receivedResponse: { _, _, _ in
        URLSessionInstrumentationTests.checker.receivedResponseCalled = true
        reported.fulfill()
      },
      receivedError: { _, _, _, _ in
        URLSessionInstrumentationTests.checker.receivedErrorCalled = true
        reported.fulfill()
      },
      ignoredClassPrefixes: [NSStringFromClass(cls)]
    )
    defer { instrumentation.configuration = original }

    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    let task = session.dataTask(with: URLRequest(url: URL(string: url)!))
    task.resume()

    wait(for: [reported], timeout: 5)

    XCTAssertNil(class_getInstanceMethod(cls, didComplete),
                 "resuming a task instrumented a delegate that ignoredClassPrefixes excludes",
                 file: file, line: line)
    XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled,
                  "the request should still be traced", file: file, line: line)
    let leaked = instrumentation.startedRequestSpans
    XCTAssertTrue(leaked.isEmpty,
                  "nothing ended the span: \(leaked.count) still running", file: file, line: line)
  }

  public func testDataTaskCompletionHandlerDoesNotLeakRequestState() {
    assertNoRequestStateLeft { session, url, completion in
      session.dataTask(with: URLRequest(url: url), completionHandler: completion)
    }
  }

  public func testUploadTaskCompletionHandlerDoesNotLeakRequestState() {
    assertNoRequestStateLeft { session, url, completion in
      session.uploadTask(with: URLRequest(url: url), from: Data(), completionHandler: completion)
    }
  }

  private func assertNoRequestStateLeft(
    makeTask: (URLSession, URL, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionTask,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    URLProtocol.registerClass(PayloadStubURLProtocol.self)
    defer { URLProtocol.unregisterClass(PayloadStubURLProtocol.self) }

    let url = URL(string: "http://\(PayloadStubURLProtocol.host)/\(UUID().uuidString)")!
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [PayloadStubURLProtocol.self]
    let session = URLSession(configuration: configuration)

    let task = makeTask(session, url) { _, _, _ in
      URLSessionInstrumentationTests.semaphore.signal()
    }
    task.resume()
    URLSessionInstrumentationTests.semaphore.wait()
    wait { task.state == .completed }

    let pending = pendingRequestStates(of: URLSessionInstrumentationTests.instrumentation)
      .filter { $0.request?.url == url }
    XCTAssertTrue(pending.isEmpty, "request state was never removed: \(pending.count) entry still held",
                  file: file, line: line)
  }

  private func pendingRequestStates(of instrumentation: URLSessionInstrumentation) -> [NetworkRequestState] {
    func child<T>(_ label: String) -> T? {
      Mirror(reflecting: instrumentation).children.first { $0.label == label }?.value as? T
    }
    guard let queue: DispatchQueue = child("queue") else { return [] }
    return queue.sync {
      let requestMap: [String: NetworkRequestState]? = child("requestMap")
      return requestMap.map { Array($0.values) } ?? []
    }
  }

  private static let didReceiveResponseSelector =
    #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))
  private static let didReceiveDataSelector = #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:))
  private static let respondsToSelector = #selector(NSObject.responds(to:))
  private static let didCompleteSelector = #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:))
  private static let didFinishCollectingSelector = #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:))

  /// Builds a session delegate class at runtime, after the startup scan has run, so that only resuming
  /// a task could instrument it. It implements the response and data callbacks and its own
  /// `respondsToSelector:`, which instrumenting swizzles, and lacks the completion and metrics
  /// callbacks, which instrumenting adds.
  private func makeUnscannedSessionDelegateClass() -> AnyClass {
    let name = "UnscannedSessionDelegate_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    let cls: AnyClass = objc_allocateClassPair(NSObject.self, name, 0)!
    class_addProtocol(cls, objc_getProtocol("NSURLSessionDataDelegate")!)

    let didReceiveResponse: @convention(block) (AnyObject, URLSession, URLSessionDataTask, URLResponse,
                                                @escaping (URLSession.ResponseDisposition) -> Void) -> Void = { _, _, _, _, completion in
      completion(.allow)
    }
    let didReceiveData: @convention(block) (AnyObject, URLSession, URLSessionDataTask, Data) -> Void = { _, _, _, _ in }
    let respondsTo: @convention(block) (AnyObject, Selector) -> Bool = { object, selector in
      class_respondsToSelector(object_getClass(object), selector)
    }
    class_addMethod(cls, Self.didReceiveResponseSelector,
                    imp_implementationWithBlock(unsafeBitCast(didReceiveResponse, to: AnyObject.self)), "v@:@@@@?")
    class_addMethod(cls, Self.didReceiveDataSelector,
                    imp_implementationWithBlock(unsafeBitCast(didReceiveData, to: AnyObject.self)), "v@:@@@")
    class_addMethod(cls, Self.respondsToSelector,
                    imp_implementationWithBlock(unsafeBitCast(respondsTo, to: AnyObject.self)), "B@::")
    objc_registerClassPair(cls)
    return cls
  }

  private func implementations(of cls: AnyClass) -> [IMP?] {
    [Self.didReceiveResponseSelector, Self.didReceiveDataSelector, Self.respondsToSelector].map {
      class_getInstanceMethod(cls, $0).map(method_getImplementation)
    }
  }

  private func resumeTask(withDelegateOf cls: AnyClass, instrumentsSessionDelegatesOnResume: Bool) {
    // The callback runs on a URLSession thread, after the span has been removed from the running
    // spans. Waiting on this expectation orders its writes before the caller's reads.
    let reported = expectation(description: "the task's response is reported")

    let instrumentation = URLSessionInstrumentationTests.instrumentation!
    let original = instrumentation.configuration
    var configuration = original
    configuration.receivedResponse = { _, _, _ in reported.fulfill() }
    configuration.instrumentsSessionDelegatesOnResume = instrumentsSessionDelegatesOnResume
    instrumentation.configuration = configuration
    defer { instrumentation.configuration = original }

    let delegate = (cls as! NSObject.Type).init() as! URLSessionDataDelegate
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    session.dataTask(with: URLRequest(url: URL(string: "http://localhost:33333/success")!)).resume()

    wait(for: [reported], timeout: 5)
  }

  public func testResumeInstrumentsUnscannedSessionDelegateByDefault() {
    let cls = makeUnscannedSessionDelegateClass()
    let before = implementations(of: cls)

    resumeTask(withDelegateOf: cls, instrumentsSessionDelegatesOnResume: true)

    let after = implementations(of: cls)
    for index in before.indices {
      XCTAssertNotEqual(before[index], after[index], "method \(index) should have been swizzled on resume")
    }
    XCTAssertNotNil(class_getInstanceMethod(cls, Self.didCompleteSelector),
                    "didCompleteWithError should have been added on resume")
    XCTAssertTrue(URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty)
  }

  public func testResumeLeavesSessionDelegateUnmodifiedWhenOptedOut() {
    let cls = makeUnscannedSessionDelegateClass()
    let before = implementations(of: cls)

    resumeTask(withDelegateOf: cls, instrumentsSessionDelegatesOnResume: false)

    let after = implementations(of: cls)
    for index in before.indices {
      XCTAssertEqual(before[index], after[index], "method \(index) was swizzled on resume")
    }
    XCTAssertNil(class_getInstanceMethod(cls, Self.didCompleteSelector),
                 "didCompleteWithError was added on resume")
    XCTAssertNil(class_getInstanceMethod(cls, Self.didFinishCollectingSelector),
                 "didFinishCollecting was added on resume")
    let leaked = URLSessionInstrumentationTests.instrumentation.startedRequestSpans
    XCTAssertTrue(leaked.isEmpty, "nothing ended the span: \(leaked.count) still running")
  }
}

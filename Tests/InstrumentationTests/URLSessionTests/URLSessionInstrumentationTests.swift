/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import URLSessionInstrumentation
import XCTest

class URLSessionInstrumentationTests: XCTestCase {
    class Check {
        public var shouldRecordPayloadCalled: Bool = false
        public var shouldInstrumentCalled: Bool = false
        public var nameSpanCalled: Bool = false
        public var setParentCalled: Bool = false
        public var shouldInjectTracingHeadersCalled: Bool = false
        public var createdRequestCalled: Bool = false
        public var receivedResponseCalled: Bool = false
        public var receivedErrorCalled: Bool = false
    }

    class SessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate {
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

    static var requestCopy: URLRequest!
    static var responseCopy: HTTPURLResponse!

    static var config = URLSessionInstrumentationConfiguration(shouldRecordPayload: nil,
                                                               shouldInstrument: { req in
                                                                   checker.shouldInstrumentCalled = true
                                                                   if req.url?.host?.contains("dontinstrument") ?? false {
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
                                                               setParent: { req in
                                                                   checker.setParentCalled = true
                                                                   if req.url?.host?.contains("defaultName") ?? false {
                                                                       return nil
                                                                   }
                                                                   return SpanContext.create(traceId: TraceId.random(),
                                                                                             spanId: SpanId.random(),
                                                                                             traceFlags: TraceFlags().settingIsSampled(true),
                                                                                             traceState: TraceState())
                                                               },
                                                               shouldInjectTracingHeaders: { _ in
                                                                   checker.shouldInjectTracingHeadersCalled = true
                                                                   return true

                                                               },
                                                               createdRequest: { request, _ in
                                                                   requestCopy = request
                                                                   checker.createdRequestCalled = true
                                                               },
                                                               receivedResponse: { response, _, _ in
                                                                   responseCopy = response as? HTTPURLResponse
                                                                   checker.receivedResponseCalled = true
                                                               },
                                                               receivedError: { _, _, _, _ in
                                                                   URLSessionInstrumentationTests.checker.receivedErrorCalled = true
                                                               })

    static var checker = Check()
    static var semaphore: DispatchSemaphore!
    var sessionDelegate: SessionDelegate!
    static var instrumentation: URLSessionInstrumentation!

    static let server = HttpTestServer(url: URL(string: "http://localhost:33333"), config: nil)

    override class func setUp() {
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
    }

    override func setUp() {
        URLSessionInstrumentationTests.checker = Check()
        URLSessionInstrumentationTests.semaphore = DispatchSemaphore(value: 0)
        sessionDelegate = SessionDelegate(semaphore: URLSessionInstrumentationTests.semaphore)
        URLSessionInstrumentationTests.requestCopy = nil
        URLSessionInstrumentationTests.responseCopy = nil
        XCTAssertEqual(0, URLSessionInstrumentationTests.instrumentation.startedRequestSpans.count)
    }

    override func tearDown() {
        URLSessionLogger.runningSpansQueue.sync {
            URLSessionLogger.runningSpans.removeAll()
        }
        XCTAssertEqual(0, URLSessionInstrumentationTests.instrumentation.startedRequestSpans.count)
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

    public func testOverrideSpanParent() {
            let request = URLRequest(url: URL(string: "http://google.com")!)

            URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

            XCTAssertTrue(URLSessionInstrumentationTests.checker.setParentCalled)

            XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
            XCTAssertNotNil(URLSessionLogger.runningSpans["id"])
            if let span = URLSessionLogger.runningSpans["id"] {
                guard let sdkSpan = span as? ReadableSpan else { return XCTFail() }
                XCTAssertNotNil(sdkSpan.toSpanData().parentSpanId)
            }
        }

    public func testDefaultSpanParent() {
        let request = URLRequest(url: URL(string: "http://defaultName.com")!)

        URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

        XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
        XCTAssertNotNil(URLSessionLogger.runningSpans["id"])
        if let span = URLSessionLogger.runningSpans["id"] {
            guard let sdkSpan = span as? ReadableSpan else { return XCTFail() }
            XCTAssertNil(sdkSpan.toSpanData().parentSpanId)
        }
    }

    public func testConfigurationCallbacksCalledWhenSuccess() {
        let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                let string = String(decoding: data, as: UTF8.self)
                print(string)
            }
            URLSessionInstrumentationTests.semaphore.signal()
        }
        task.resume()

        URLSessionInstrumentationTests.semaphore.wait()

        XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.setParentCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    }

    public func testConfigurationCallbacksCalledWhenForbidden() {
        let request = URLRequest(url: URL(string: "http://localhost:33333/forbidden")!)
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                let string = String(decoding: data, as: UTF8.self)
                print(string)
            }
            URLSessionInstrumentationTests.semaphore.signal()
        }
        task.resume()

        URLSessionInstrumentationTests.semaphore.wait()

        XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.nameSpanCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.setParentCalled)
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
        XCTAssertTrue(URLSessionInstrumentationTests.checker.setParentCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
        XCTAssertFalse(URLSessionInstrumentationTests.checker.receivedResponseCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedErrorCalled)
    }

    public func testShouldInstrumentRequest() {
        let request1 = URLRequest(url: URL(string: "http://defaultName.com")!)
        let request2 = URLRequest(url: URL(string: "http://dontinstrument.com")!)

        URLSessionLogger.processAndLogRequest(request1, sessionTaskId: "111", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)
        URLSessionLogger.processAndLogRequest(request2, sessionTaskId: "222", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

        XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)

        XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
        XCTAssertNotNil(URLSessionLogger.runningSpans["111"])
        if let span = URLSessionLogger.runningSpans["111"] {
            XCTAssertEqual("HTTP GET", span.name)
        }
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
}

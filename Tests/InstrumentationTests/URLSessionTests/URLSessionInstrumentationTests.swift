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
        public var spanCustomizationCalled: Bool = false
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

    static var activeBaggage: Baggage!
    static var defaultBaggage: Baggage!

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
                                                               },
                                                               defaultBaggageProvider: {
                                                                   defaultBaggage
                                                               })

    static var checker = Check()
    static var semaphore: DispatchSemaphore!
    var sessionDelegate: SessionDelegate!
    static var instrumentation: URLSessionInstrumentation!

    static let server = HttpTestServer(url: URL(string: "http://localhost:33333"), config: nil)

    override class func setUp() {
        OpenTelemetry.registerPropagators(textPropagators: [W3CTraceContextPropagator()], baggagePropagator: W3CBaggagePropagator())
        OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderSdk())

        defaultBaggage = DefaultBaggageManager.instance.baggageBuilder()
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
        defaultBaggage = nil
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(activeBaggage)
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
        XCTAssertTrue(URLSessionInstrumentationTests.checker.spanCustomizationCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInjectTracingHeadersCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
        XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
    }

    public func testConfigurationCallbacksCalledWhenForbidden() throws {
        #if os(watchOS)
            throw XCTSkip("Implementation needs to be updated for watchOS to make this test pass")
        #endif

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

        let processedRequest1 = try XCTUnwrap(URLSessionLogger.processAndLogRequest(request1, sessionTaskId: "111", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true))
        let processedRequest2 = URLSessionLogger.processAndLogRequest(request2, sessionTaskId: "222", instrumentation: URLSessionInstrumentationTests.instrumentation, shouldInjectHeaders: true)

        // `processedRequest2` is expected to be nil, because its URL was marked as not to be instrumented.
        XCTAssertNil(processedRequest2)

        XCTAssertTrue(URLSessionInstrumentationTests.checker.shouldInstrumentCalled)

        XCTAssertEqual(1, URLSessionLogger.runningSpans.count)

        let span = try XCTUnwrap(URLSessionLogger.runningSpans["111"])
        XCTAssertEqual("HTTP GET", span.name)
    }

    public func testShouldInstrumentRequest_PropagateCombinedActiveAndDefaultBaggages() throws {
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

        // bar=baz propagated through default baggage provided in `URLSessionInstrumentationConfiguration`
        XCTAssertTrue(baggageHeaderValue.contains("bar=baz"))

        XCTAssertEqual(1, URLSessionLogger.runningSpans.count)

        let span = try XCTUnwrap(URLSessionLogger.runningSpans["111"])
        XCTAssertEqual("HTTP GET", span.name)
    }

    public func testShouldInstrumentRequest_PropagateOnlyActiveBaggage() throws {
        Self.defaultBaggage = nil

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
    
    #if swift(>=5.5.2)
        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        public func testConfigurationCallbacksCalledWhenSuccessAsync() async throws {
            let request = URLRequest(url: URL(string: "http://localhost:33333/success")!)

            let (data, _) = try await URLSession.shared.data(for: request)
            let string = String(decoding: data, as: UTF8.self)
            print(string)

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
            } catch {
            }

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

            let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
            _ = try await session.data(for: request)

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
        public func testDownloadTaskWithRequestDelegateAsync() async throws {
            let url = URL(string: "http://localhost:33333/success")!
            let request = URLRequest(url: url)

            let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
            _ = try await session.download(for: request)

            XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
            XCTAssertTrue(URLSessionInstrumentationTests.checker.receivedResponseCalled)
            XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
        }

        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        public func testUploadTaskWithRequestDelegateAsync() async throws {
            let url = URL(string: "http://localhost:33333/success")!
            let request = URLRequest(url: url)
            let session = URLSession(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: nil)
            _ = try await session.upload(for: request, from: Data())

            XCTAssertTrue(URLSessionInstrumentationTests.checker.createdRequestCalled)
            XCTAssertNotNil(URLSessionInstrumentationTests.requestCopy?.allHTTPHeaderFields?[W3CTraceContextPropagator.traceparent])
        }

    #endif
}

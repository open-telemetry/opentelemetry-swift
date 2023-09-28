/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import os.log
#if os(iOS) && !targetEnvironment(macCatalyst)
    import NetworkStatus
#endif // os(iOS) && !targetEnvironment(macCatalyst)

class URLSessionLogger {
    static var runningSpans = [String: Span]()
    static var runningSpansQueue = DispatchQueue(label: "io.opentelemetry.URLSessionLogger")
    #if os(iOS) && !targetEnvironment(macCatalyst)

        static var netstatInjector: NetworkStatusInjector? = { () -> NetworkStatusInjector? in
            do {
                let netstats = try NetworkStatus()
                return NetworkStatusInjector(netstat: netstats)
            } catch {
                if #available(iOS 14, macOS 11, tvOS 14, *) {
                    os_log(.error, "failed to initialize network connection status: %@", error.localizedDescription)
                } else {
                    NSLog("failed to initialize network connection status: %@", error.localizedDescription)
                }

                return nil
            }
        }()
    #endif // os(iOS) && !targetEnvironment(macCatalyst)

    /// This methods creates a Span for a request, and optionally injects tracing headers, returns a  new request if it was needed to create a new one to add the tracing headers
    @discardableResult static func processAndLogRequest(_ request: URLRequest, sessionTaskId: String, instrumentation: URLSessionInstrumentation, shouldInjectHeaders: Bool) -> URLRequest? {
        guard instrumentation.configuration.shouldInstrument?(request) ?? true else {
            return nil
        }

        var attributes = [String: AttributeValue]()

        attributes[SemanticAttributes.httpMethod.rawValue] = AttributeValue.string(request.httpMethod ?? "unknown_method")

        if let requestURL = request.url {
            attributes[SemanticAttributes.httpUrl.rawValue] = AttributeValue.string(requestURL.absoluteString)
        }

        if let requestURLPath = request.url?.path {
            attributes[SemanticAttributes.httpTarget.rawValue] = AttributeValue.string(requestURLPath)
        }

        if let host = request.url?.host {
            attributes[SemanticAttributes.netPeerName.rawValue] = AttributeValue.string(host)
        }

        if let requestScheme = request.url?.scheme {
            attributes[SemanticAttributes.httpScheme.rawValue] = AttributeValue.string(requestScheme)
        }

        if let port = request.url?.port {
            attributes[SemanticAttributes.netPeerPort.rawValue] = AttributeValue.int(port)
        }
        
        if let bodySize = request.httpBody?.count {
            attributes[SemanticAttributes.httpRequestBodySize.rawValue] = AttributeValue.int(bodySize)
        }

        var spanName = "HTTP " + (request.httpMethod ?? "")
        if let customSpanName = instrumentation.configuration.nameSpan?(request) {
            spanName = customSpanName
        }
        let spanBuilder = instrumentation.tracer.spanBuilder(spanName: spanName)
        spanBuilder.setSpanKind(spanKind: .client)
        attributes.forEach {
            spanBuilder.setAttribute(key: $0.key, value: $0.value)
        }
        instrumentation.configuration.spanCustomization?(request, spanBuilder)

        let span = spanBuilder.startSpan()
        runningSpansQueue.sync {
            runningSpans[sessionTaskId] = span
        }

        var returnRequest: URLRequest?
        if shouldInjectHeaders, instrumentation.configuration.shouldInjectTracingHeaders?(request) ?? true {
            returnRequest = instrumentedRequest(for: request, span: span, instrumentation: instrumentation)
        }

        #if os(iOS) && !targetEnvironment(macCatalyst)
            if let injector = netstatInjector {
                injector.inject(span: span)
            }
        #endif

        instrumentation.configuration.createdRequest?(returnRequest ?? request, span)

        return returnRequest
    }

    /// This methods ends a Span when a response arrives
    static func logResponse(_ response: URLResponse, dataOrFile: Any?, instrumentation: URLSessionInstrumentation, sessionTaskId: String) {
        var span: Span!
        runningSpansQueue.sync {
            span = runningSpans.removeValue(forKey: sessionTaskId)
        }
        guard span != nil,
              let httpResponse = response as? HTTPURLResponse
        else {
            return
        }

        let statusCode = httpResponse.statusCode
        span.setAttribute(key: SemanticAttributes.httpStatusCode.rawValue, 
                          value: AttributeValue.int(statusCode))
        span.status = statusForStatusCode(code: statusCode)

        if let contentLengthHeader = httpResponse.allHeaderFields["Content-Length"] as? String,
           let contentLength = Int(contentLengthHeader) {
            span.setAttribute(key: SemanticAttributes.httpResponseBodySize.rawValue,
                              value: AttributeValue.int(contentLength))
        }

        instrumentation.configuration.receivedResponse?(response, dataOrFile, span)
        span.end()
    }

    /// This methods ends a Span when a error arrives
    static func logError(_ error: Error, dataOrFile: Any?, statusCode: Int, instrumentation: URLSessionInstrumentation, sessionTaskId: String) {
        var span: Span!
        runningSpansQueue.sync {
            span = runningSpans.removeValue(forKey: sessionTaskId)
        }
        guard span != nil else {
            return
        }
        span.setAttribute(key: SemanticAttributes.httpStatusCode.rawValue, value: AttributeValue.int(statusCode))
        span.status = URLSessionLogger.statusForStatusCode(code: statusCode)
        instrumentation.configuration.receivedError?(error, dataOrFile, statusCode, span)

        span.end()
    }

    private static func statusForStatusCode(code: Int) -> Status {
        switch code {
        case 100 ... 399:
            return .unset
        default:
            return .error(description: String(code))
        }
    }

    private static func instrumentedRequest(for request: URLRequest, span: Span?, instrumentation: URLSessionInstrumentation) -> URLRequest? {
        var request = request
        guard instrumentation.configuration.shouldInjectTracingHeaders?(request) ?? true
        else {
            return nil
        }
        instrumentation.configuration.injectCustomHeaders?(&request, span)
        var instrumentedRequest = request
        objc_setAssociatedObject(instrumentedRequest, &URLSessionInstrumentation.instrumentedKey, true, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        let propagators = OpenTelemetry.instance.propagators
        var traceHeaders = tracePropagationHTTPHeaders(span: span, textMapPropagator: propagators.textMapPropagator, textMapBaggagePropagator: propagators.textMapBaggagePropagator)
        if let originalHeaders = request.allHTTPHeaderFields {
            traceHeaders.merge(originalHeaders) { _, new in new }
        }
        instrumentedRequest.allHTTPHeaderFields = traceHeaders
        return instrumentedRequest
    }

    private static func tracePropagationHTTPHeaders(span: Span?, textMapPropagator: TextMapPropagator, textMapBaggagePropagator: TextMapBaggagePropagator) -> [String: String] {
        var headers = [String: String]()

        struct HeaderSetter: Setter {
            func set(carrier: inout [String: String], key: String, value: String) {
                carrier[key] = value
            }
        }

        guard let currentSpan = span ?? OpenTelemetry.instance.contextProvider.activeSpan else {
            return headers
        }
        textMapPropagator.inject(spanContext: currentSpan.context, carrier: &headers, setter: HeaderSetter())

        if let baggage = OpenTelemetry.instance.contextProvider.activeBaggage {
            textMapBaggagePropagator.inject(baggage: baggage, carrier: &headers, setter: HeaderSetter())
        }
        return headers
    }
}

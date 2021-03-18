/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal protocol URLSessionInterceptorType: class {
    func modify(request: URLRequest) -> URLRequest
    func taskCreated(task: URLSessionTask)
    func taskMetricsCollected(task: URLSessionTask, metrics: URLSessionTaskMetrics)
    func taskCompleted(task: URLSessionTask, error: Error?)
}

/// An object performing interception of requests sent with `URLSession`.
public class URLSessionInterceptor: URLSessionInterceptorType {
    public static var shared: URLSessionInterceptor? {
        URLSessionAutoInstrumentation.instance?.interceptor
    }

    var tracer : TracerSdk

    /// Filters first party `URLs` defined by the user.
//    private let firstPartyURLsFilter: FirstPartyURLsFilter
//    /// Filters internal `URLs` used by the SDK.
//    private let internalURLsFilter: InternalURLsFilter
    /// Handles resources interception.
    /// Depending on which instrumentation is enabled, this can be either RUM or Tracing handler sending respectively: RUM Resource or tracing Span.
    internal let handler: URLSessionInterceptionHandler =  URLSessionTracingHandler()

    /// Whether or not to inject tracing headers to intercepted 1st party requests.
    /// Set to `true` if Tracing instrumentation is enabled (no matter o RUM state).
    internal let injectTracingHeadersToFirstPartyRequests: Bool
    /// Additional header injected to intercepted 1st party requests.
    /// Set to `x-datadog-origin: rum` if both RUM and Tracing instrumentations are enabled and `nil` in all other cases.
    internal let additionalHeadersForFirstPartyRequests: [String: String]?

    // MARK: - Initialization


    init(
        tracer: TracerSdk
    ) {
        self.tracer = tracer
//        var handler = URLSessionTracingHandler()

//        self.handler = handler
            
//        if configuration.instrumentTracing {
//            self.injectTracingHeadersToFirstPartyRequests = true

//            if configuration.instrumentRUM {
                // If RUM instrumentation is enabled, additional `x-datadog-origin: rum` header is injected to the user request,
                // so that user's backend instrumentation can further process it and count on RUM quota.
//                self.additionalHeadersForFirstPartyRequests = [
//                    TracingHTTPHeaders.originField: TracingHTTPHeaders.rumOriginValue
//                ]
//            } else {
//                self.additionalHeadersForFirstPartyRequests = nil
//            }
//        } else {
            self.injectTracingHeadersToFirstPartyRequests = false
            self.additionalHeadersForFirstPartyRequests = nil
//        }
    }

    /// An internal queue for synchronising the access to `interceptionByTask`.
    private let queue = DispatchQueue(label: "com.datadoghq.URLSessionInterceptor", target: .global(qos: .utility))
    /// Maps `URLSessionTask` to its `TaskInterception` object.
    private var interceptionByTask: [URLSessionTask: TaskInterception] = [:]

    // MARK: - Public

    /// Intercepts given `URLRequest` before it is sent.
    /// If Tracing feature is enabled and first party hosts are configured in `Datadog.Configuration`, this method will
    /// modify the `request` by adding Datadog trace propagation headers. This will enable end-to-end trace propagation
    /// from the client application to backend services instrumented with Datadog agents.
    /// - Parameter request: input request.
    /// - Returns: modified input requests. The modified request may contain additional Datadog headers.
    public func modify(request: URLRequest) -> URLRequest {
        
//        guard !internalURLsFilter.isInternal(url: request.url) else {
//            return request
        
//        if injectTracingHeadersToFirstPartyRequests,
//           firstPartyURLsFilter.isFirstParty(url: request.url) {
            return injectSpanContext(into: request)
//        }
//        return request
    }

    /// Notifies the `URLSessionTask` creation.
    /// This method should be called as soon as the task was created.
    /// - Parameter task: the task object obtained from `URLSession`.
    public func taskCreated(task: URLSessionTask) {
        guard let request = task.originalRequest else {
//              !internalURLsFilter.isInternal(url: request.url) else {
            return
        }

        queue.async {
            let interception = TaskInterception(
                request: request,
                isFirstParty: true //self.firstPartyURLsFilter.isFirstParty(url: request.url)
                    //todo: update firstpartyURLFilter
            )
            self.interceptionByTask[task] = interception

            if let spanContext = self.extractSpanContext(from: request) {
                interception.register(spanContext: spanContext)
            }

            self.handler.notify_taskInterceptionStarted(interception: interception)
        }
    }

    /// Notifies the `URLSessionTask` metrics collection.
    /// This method should be called as soon as the task metrics were received by `URLSessionDelegate`.
    /// - Parameters:
    ///   - task: task receiving metrics.
    ///   - metrics: metrics object delivered to `URLSessionDelegate`.
    public func taskMetricsCollected(task: URLSessionTask, metrics: URLSessionTaskMetrics) {
//        guard !internalURLsFilter.isInternal(url: task.originalRequest?.url) else {
//            return
//        }

        queue.async {
            guard let interception = self.interceptionByTask[task] else {
                return
            }

            interception.register(
                metrics: ResourceMetrics(taskMetrics: metrics)
            )

            if interception.isDone {
                self.finishInterception(task: task, interception: interception)
            }
        }
    }

    /// Notifies the `URLSessionTask` completion.
    /// This method should be called as soon as the task was completed.
    /// - Parameter task: the task object obtained from `URLSession`.
    /// - Parameter error: optional `Error` if the task completed with error.
    public func taskCompleted(task: URLSessionTask, error: Error?) {

//        guard !internalURLsFilter.isInternal(url: task.originalRequest?.url) else {
//            return
//        }

        queue.async {
            guard let interception = self.interceptionByTask[task] else {
                return
            }
//
            interception.register(
                completion: ResourceCompletion(response: task.response, error: error)
            )

            if interception.isDone {
                self.finishInterception(task: task, interception: interception)
            }
        }
    }

    // MARK: - Private

    private func finishInterception(task: URLSessionTask, interception: TaskInterception) {
        interceptionByTask[task] = nil
        handler.notify_taskInterceptionCompleted(interception: interception)
    }

    // MARK: - Span Injection & Extraction

    private func injectSpanContext(into firstPartyRequest: URLRequest) -> URLRequest {
        guard var _ = URLSessionAutoInstrumentation.instance?.tracer else {
            return firstPartyRequest
        }

//        tracer.inject()
        let writer = HTTPHeadersWriter()
        let spanContext = SpanContext.create(traceId: TraceId.random(),
                                             spanId: SpanId.random(),
                                             traceFlags: TraceFlags().settingIsSampled(true),
                                             traceState: TraceState())
        
        //

        
        var newRequest = firstPartyRequest
        writer.inject(spanContext: spanContext)
        writer.tracePropagationHTTPHeaders.forEach { field, value in
            newRequest.setValue(value, forHTTPHeaderField: field)
        }
//
//        additionalHeadersForFirstPartyRequests?.forEach { field, value in
//            newRequest.setValue(value, forHTTPHeaderField: field)
//        }

        //todo: fill this in.
        return newRequest
    }

    private func extractSpanContext(from request: URLRequest) -> SpanContext? {
        guard let _ = URLSessionAutoInstrumentation.instance?.tracer,
              let headers = request.allHTTPHeaderFields else {
            return nil
        }

        let reader = HTTPHeadersReader(httpHeaderFields: headers)
        if let extractedContext = reader.extract() {
            return SpanContext.create(traceId: extractedContext.traceId,
                                      spanId: extractedContext.spanId,
                                      traceFlags: extractedContext.traceFlags,
                                      traceState:extractedContext.traceState)
        }
        return nil
    }
}

/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal class URLSessionTracingHandler: URLSessionInterceptionHandler {
    // MARK: - URLSessionInterceptionHandler

    func notify_taskInterceptionStarted(interception: TaskInterception) {
        /* no-op */
    }

    func notify_taskInterceptionCompleted(interception: TaskInterception) {
        if !interception.isFirstPartyRequest {
            return // `Span` should be only send for 1st party requests
        }
        guard let tracer = URLSessionAutoInstrumentation.instance?.tracer else {
//            userLogger.warn(
//                """
//                `URLSession` request was completed, but no `Tracer` is registered on `Global.sharedTracer`. Tracing auto instrumentation will not work.
//                Make sure `Global.sharedTracer = Tracer.initialize()` is called before any network request is send.
//                """
//            )
            return
        }
        guard let resourceMetrics = interception.metrics,
         let resourceCompletion = interception.completion else {
            return
        }

        let span: Span
//
        let url = interception.request.url?.absoluteString ?? "unknown_url"
        let method = interception.request.httpMethod ?? "unknown_method"
        if let spanContext = interception.spanContext {
            span = RecordEventsReadableSpan.startSpan(context: spanContext,
                name: "\(method) \(url)",
                instrumentationLibraryInfo: tracer.instrumentationLibraryInfo,
                kind: .client,
                parentContext: nil,
                hasRemoteParent: false,
                traceConfig: tracer.sharedState.activeTraceConfig,
                spanProcessor: tracer.sharedState.activeSpanProcessor,
                clock: tracer.sharedState.clock,
                resource: tracer.sharedState.resource,
                attributes: AttributesDictionary(capacity: tracer.sharedState.activeTraceConfig.maxNumberOfAttributes),
                links: [SpanData.Link](),
                totalRecordedLinks:0,
                startTime: resourceMetrics.fetch.start)
        } else {
//            // Span context may not be injected on iOS13+ if `URLSession.dataTask(...)` for `URL`
//            // was used to create the session task.
            span = tracer.spanBuilder(spanName: "\(method) \(url)")
                    .setSpanKind(spanKind: .client)
                    .setStartTime(time: resourceMetrics.fetch.start)
                    .setNoParent()
                    .startSpan()
        }


        span.setAttribute(key: .httpURL, value: url)
        span.setAttribute(key: .httpMethod, value: method)

        if let httpResponseStatusCode = resourceCompletion.httpResponse?.statusCode {
        span.putHttpStatusCode(statusCode: httpResponseStatusCode, reasonPhrase: resourceCompletion.error?.localizedDescription ?? "" )
        } else if let error = resourceCompletion.error as? URLError {
            span.status = Status.error.withDescription(description: "\(URLError.errorDomain): \(error.localizedDescription)")
            
            span.addEvent(name: TraceConstants.exception.rawValue,
                          attributes: [TraceConstants.exceptionType.rawValue : AttributeValue.string(String(describing: type(of: error))),
                                       TraceConstants.exceptionEscaped.rawValue : AttributeValue.bool(false),
                                       TraceConstants.exceptionMessage.rawValue : AttributeValue.string(error.localizedDescription)],
                          timestamp: resourceMetrics.fetch.end)
        }

        span.end(time: resourceMetrics.fetch.end)

    }
}


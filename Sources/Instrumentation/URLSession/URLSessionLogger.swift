// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

class URLSessionLogger {
    static var runningSpans = [String: Span]()
    static var runningSpansQueue = DispatchQueue(label: "org.opentelemetry.URLSessionLogger")

    static func logRequest(_ request: URLRequest, instrumentation: URLSessionInstrumentation, sessionTaskId: String) {
        guard instrumentation.configuration.shouldInstrument?(request) ?? true else {
            return
        }

        var attributes = [String: String]()

        attributes[SemanticAttributes.httpMethod.rawValue] = request.httpMethod ?? "unknown_method"

        if let requestURL = request.url {
            attributes[SemanticAttributes.httpURL.rawValue] = requestURL.absoluteString
        }

        if let requestURLPath = request.url?.path {
            attributes[SemanticAttributes.httpTarget.rawValue] = requestURLPath
        }

        if let host = request.url?.host {
            attributes[SemanticAttributes.netPeerName.rawValue] = host
        }

        if let requestScheme = request.url?.scheme {
            attributes[SemanticAttributes.httpScheme.rawValue] = requestScheme
        }

        if let port = request.url?.port {
            attributes[SemanticAttributes.netPeerPort.rawValue] = String(port)
        }

        let spanName = "HTTP " + (request.httpMethod ?? "")
        let spanBuilder = instrumentation.tracer.spanBuilder(spanName: spanName)
        spanBuilder.setSpanKind(spanKind: .client)
        attributes.forEach {
            spanBuilder.setAttribute(key: $0.key, value: $0.value)
        }

        instrumentation.configuration.createdRequest?(request, spanBuilder)

        let span = spanBuilder.startSpan()
        runningSpansQueue.sync {
            runningSpans[sessionTaskId] = span
        }
    }

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
        span.setAttribute(key: SemanticAttributes.httpStatusCode.rawValue, value: AttributeValue.string(String(statusCode)))
        span.status = statusForStatusCode(code: statusCode)

        instrumentation.configuration.receivedResponse?(response, dataOrFile, span)
        span.end()
    }

    static func logError(_ error: Error, dataOrFile: Any?, statusCode: Int, instrumentation: URLSessionInstrumentation, sessionTaskId: String) {
        var span: Span!
        runningSpansQueue.sync {
            span = runningSpans.removeValue(forKey: sessionTaskId)
        }
        guard span != nil else {
            return
        }
        span.setAttribute(key: SemanticAttributes.httpStatusCode.rawValue, value: AttributeValue.string(String(statusCode)))
        span.status = URLSessionLogger.statusForStatusCode(code: statusCode)
        instrumentation.configuration.receivedError?(error, dataOrFile, statusCode, span)

        span.end()
    }

    static func statusForStatusCode(code: Int) -> Status {
        switch code {
            case 100 ... 399:
                return .unset
            default:
                return .error(description: String(code))
        }
    }
}

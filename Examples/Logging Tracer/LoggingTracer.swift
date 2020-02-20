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

class LoggingTracer: Tracer {
    let tracerName = "LoggingTracer"
    public var currentSpan: Span? {
        return ContextUtils.getCurrentSpan()
    }

    var binaryFormat: BinaryFormattable = BinaryTraceContextFormat()
    var textFormat: TextFormattable = HttpTraceContextFormat()

    func spanBuilder(spanName: String) -> SpanBuilder {
        return LoggingSpanBuilder(tracer: self, spanName: spanName)
    }

    func withSpan(_ span: Span) -> Scope {
        Logger.log("\(tracerName).WithSpan")
        return ContextUtils.withSpan(span)
    }

    class LoggingSpanBuilder: SpanBuilder {
        private var tracer: Tracer
        private var isRootSpan: Bool = false
        private var spanContext: SpanContext?
        private var name: String

        init(tracer: Tracer, spanName: String) {
            self.tracer = tracer
            name = spanName
        }

        func startSpan() -> Span {
            if spanContext == nil && !isRootSpan {
                spanContext = tracer.currentSpan?.context
            }
            return spanContext != nil && spanContext != SpanContext.invalid ? LoggingSpan(name: name, kind: .client) : DefaultSpan.random()
        }

        func setParent(_ parent: Span) -> Self {
            spanContext = parent.context
            return self
        }

        func setParent(_ parent: SpanContext) -> Self {
            spanContext = parent
            return self
        }

        func setNoParent() -> Self {
            isRootSpan = true
            return self
        }

        func addLink(spanContext: SpanContext) -> Self {
            return self
        }

        func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) -> Self {
            return self
        }

        func addLink(_ link: Link) -> Self {
            return self
        }

        func setSpanKind(spanKind: SpanKind) -> Self {
            return self
        }

        func setStartTimestamp(startTimestamp: Int) -> Self {
            return self
        }

        func setAttribute(key: String, value: AttributeValue) -> Self {
            return self
        }
    }
}

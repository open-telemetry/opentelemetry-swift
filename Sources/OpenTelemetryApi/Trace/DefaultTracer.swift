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

/// No-op implementation of the Tracer
public class DefaultTracer: Tracer {
    public static var instance = DefaultTracer()
    public var binaryFormat: BinaryFormattable = BinaryTraceContextFormat()
    public var textFormat: TextFormattable = HttpTraceContextFormat()

    private init() {}

    public var currentSpan: Span? {
        return ContextUtils.getCurrentSpan()
    }

    public func withSpan(_ span: Span) -> Scope {
        return SpanInScope(span: span)
    }

    public func spanBuilder(spanName: String) -> SpanBuilder {
        return DefaultSpanBuilder(tracer: self, spanName: spanName)
    }
}

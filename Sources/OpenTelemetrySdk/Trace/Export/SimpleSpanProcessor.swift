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

/// An implementation of the SpanProcessor that converts the ReadableSpan SpanData
///  and passes it to the configured exporter.
public struct SimpleSpanProcessor: SpanProcessor {
    private var spanExporter: SpanExporter
    private var sampled: Bool = true

    public func onStart(span: ReadableSpan) {
    }

    public mutating func onEnd(span: ReadableSpan) {
        if sampled && !span.context.traceFlags.sampled {
            return
        }
        let span = span.toSpanData()
        spanExporter.export(spans: [span])
    }

    public mutating func shutdown() {
        spanExporter.shutdown()
    }

    /// Returns a new SimpleSpansProcessor that converts spans to proto and forwards them to
    /// the given spanExporter.
    /// - Parameter spanExporter: the SpanExporter to where the Spans are pushed.
    public init(spanExporter: SpanExporter) {
        self.spanExporter = spanExporter
    }

    /// Set whether only sampled spans should be reported.
    /// - Parameter sampled: report only sampled spans.
    public func reportingOnlySampled(sampled: Bool) -> Self {
        var processor = self
        processor.sampled = sampled
        return processor
    }
}

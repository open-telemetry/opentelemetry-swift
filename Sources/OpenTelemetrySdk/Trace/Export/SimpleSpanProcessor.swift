/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// An implementation of the SpanProcessor that converts the ReadableSpan SpanData
///  and passes it to the configured exporter.
public struct SimpleSpanProcessor: SpanProcessor {
    private var spanExporter: SpanExporter
    private var sampled: Bool = true

    public let isStartRequired = false
    public let isEndRequired = true
    
    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    }

    public mutating func onEnd(span: ReadableSpan) {
        if sampled && !span.context.traceFlags.sampled {
            return
        }
        let span = span.toSpanData()
        spanExporter.export(spans: [span])
    }

    public func shutdown() {
        spanExporter.shutdown()
    }

    public func forceFlush() {
        _ = spanExporter.flush()
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

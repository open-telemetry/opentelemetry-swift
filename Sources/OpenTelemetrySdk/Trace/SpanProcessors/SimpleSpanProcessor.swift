/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// A really simple implementation of the SpanProcessor that converts the ReadableSpan SpanData
/// and passes it to the configured exporter.
/// For production environment BatchSpanProcessor is configurable and is preferred.
public struct SimpleSpanProcessor: SpanProcessor {
  private let spanExporter: SpanExporter
  private var sampled: Bool = true
  private let processorQueue = DispatchQueue(label: "io.opentelemetry.simplespanprocessor")
  
  public let isStartRequired = false
  public let isEndRequired = true
  
  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {}
  
  public mutating func onEnd(span: ReadableSpan) {
    if sampled, !span.context.traceFlags.sampled {
      return
    }
    let span = span.toSpanData()
    let spanExporterAux = self.spanExporter
    processorQueue.async {
      _ = spanExporterAux.export(spans: [span])
    }
  }
  
  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    processorQueue.sync {
      spanExporter.shutdown(explicitTimeout: explicitTimeout)
    }
  }
  
  /// Forces the processing of the remaining spans
  /// - Parameter timeout: unused in this processor
  public func forceFlush(timeout: TimeInterval? = nil) {
    processorQueue.sync {
      _ = spanExporter.flush()
    }
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

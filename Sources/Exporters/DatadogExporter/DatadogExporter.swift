/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public class DatadogExporter: SpanExporter, MetricExporter {
  let configuration: ExporterConfiguration
  var spansExporter: SpansExporter?
  var logsExporter: LogsExporter?
  var metricsExporter: MetricsExporter?

  public init(config: ExporterConfiguration) throws {
    configuration = config
    spansExporter = try SpansExporter(config: configuration)
    logsExporter = try LogsExporter(config: configuration)
    metricsExporter = try MetricsExporter(config: configuration)
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    spans.forEach {
      if $0.traceFlags.sampled || configuration.exportUnsampledSpans {
        spansExporter?.exportSpan(span: $0)
      }
      if $0.traceFlags.sampled || configuration.exportUnsampledLogs {
        logsExporter?.exportLogs(fromSpan: $0)
      }
    }
    return .success
  }

  public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
    metrics.forEach {
      metricsExporter?.exportMetric(metric: $0)
    }
    return .success
  }

  public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    spansExporter?.tracesStorage.writer.queue.sync {}
    logsExporter?.logsStorage.writer.queue.sync {}
    metricsExporter?.metricsStorage.writer.queue.sync {}

    _ = logsExporter?.logsUpload.uploader.flush()
    _ = spansExporter?.tracesUpload.uploader.flush()
    _ = metricsExporter?.metricsUpload.uploader.flush()
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    _ = flush()
  }

  public func endpointURLs() -> Set<String> {
    return [configuration.endpoint.logsURL.absoluteString,
            configuration.endpoint.tracesURL.absoluteString,
            configuration.endpoint.metricsURL.absoluteString]
  }
}

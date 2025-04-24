/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// A Grafana Faro exporter that supports both traces and logs in a single instance.
///
/// The FaroExporter sends telemetry data to Grafana Faro, which can be either cloud-hosted (Grafana Cloud)
/// or self-hosted using Grafana Alloy. It supports both traces and logs through the same exporter instance,
/// allowing for efficient telemetry collection.
///
/// For Grafana Cloud users, you can find your collector URL in the Frontend Observability configuration section.
/// For self-hosted setups using Grafana Alloy, refer to the [Quick Start Guide](https://github.com/grafana/faro-web-sdk/blob/main/docs/sources/tutorials/quick-start-browser.md).
///
/// Example configuration:
/// ```swift
/// let faroOptions = FaroExporterOptions(
///     collectorUrl: "http://your-faro-collector.net/collect/YOUR_API_KEY",
///     appName: "your-app-name",
///     appVersion: "1.0.0",
///     appEnvironment: "production"
/// )
/// ```
///
/// Example setup for traces:
/// ```swift
/// // Create the Faro exporter
/// let faroExporter = try! FaroExporter(options: faroOptions)
///
/// // Create a span processor with the Faro exporter
/// let faroProcessor = BatchSpanProcessor(spanExporter: faroExporter)
///
/// // Configure the tracer provider
/// let tracerProvider = TracerProviderBuilder()
///     .add(spanProcessor: faroProcessor)
///     ...
///     .build()
/// ```
///
/// Example setup for logs:
/// ```swift
/// // Create the Faro exporter (or reuse the one from traces)
/// let faroExporter = try! FaroExporter(options: faroOptions)
///
/// // Create a log processor with the Faro exporter
/// let faroProcessor = BatchLogRecordProcessor(logRecordExporter: faroExporter)
///
/// // Configure the logger provider
/// let loggerProvider = LoggerProviderBuilder()
///     .with(processors: [faroProcessor])
///     ...
///     .build()
/// ```
public final class FaroExporter: SpanExporter, LogRecordExporter {
  private let faroManager: FaroManager

  /// Initialize a new Faro exporter instance
  /// - Parameter options: Configuration options
  /// - Throws: FaroExporterError if configuration is invalid
  public init(options: FaroExporterOptions) throws {
    faroManager = try FaroManagerFactory.getInstance(options: options)
  }

  // MARK: - SpanExporter Implementation

  public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    // Push spans as normal
    faroManager.pushSpans(spans)

    // Additionally create and push a Faro event for each span
    let events = spans.compactMap { span -> FaroEvent? in
      guard let traceContext = span.getFaroTraceContext() else { return nil }

      return FaroEvent.create(
        name: span.getFaroEventName(),
        attributes: span.getFaroEventAttributes(),
        trace: traceContext
      )
    }

    if !events.isEmpty {
      faroManager.pushEvents(events: events)
    }

    return .success
  }

  public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval?) {}

  // MARK: - LogRecordExporter Implementation

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: logRecords)
    faroManager.pushLogs(faroLogs)
    return .success
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  public func shutdown() async {}
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// Main exporter class implementing OTel protocols for Grafana Faro
public final class FaroExporter: SpanExporter, LogRecordExporter {
  private let faroManager: FaroManager

  static let version = "1.0.0"

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

    // Additionally create and push an event for each span
    let events = spans.compactMap { span -> FaroEvent? in
      // Create a Faro event from each span
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

  public func flush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.SpanExporterResultCode {
    return .success // TODO: fix real code
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    // TODO: fix real code
  }

  // MARK: - LogRecordExporter Implementation

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: logRecords)
    faroManager.pushLogs(faroLogs)
    return .success
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
    return .success // TODO: fix real code
  }

  // MARK: - Shutdown

  public func shutdown() async {}
}

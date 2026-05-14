/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

public final class OtlpTraceJsonExporter: SpanExporter, @unchecked Sendable {
  // MARK: - Variables declaration

  private let lock = NSLock()
  private var exportedSpans = [OtlpSpan]()
  private var isRunning: Bool = true

  // MARK: - Json Exporter helper methods

  public func getExportedSpans() -> [OtlpSpan] {
    lock.withLock { exportedSpans }
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    let running = lock.withLock { isRunning }
    guard running else { return .failure }

    let exportRequest = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
      $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
    }

    do {
      let jsonData = try exportRequest.jsonUTF8Data()
      do {
        let span = try JSONDecoder().decode(OtlpSpan.self, from: jsonData)
        lock.withLock { exportedSpans.append(span) }
      } catch {
        OpenTelemetry.instance.feedbackHandler?("Decode Error: \(error)")
      }
      return .success
    } catch {
      return .failure
    }
  }

  public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    return lock.withLock { isRunning ? .success : .failure }
  }

  public func reset() {
    lock.withLock { exportedSpans.removeAll() }
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    lock.withLock {
      exportedSpans.removeAll()
      isRunning = false
    }
  }
}

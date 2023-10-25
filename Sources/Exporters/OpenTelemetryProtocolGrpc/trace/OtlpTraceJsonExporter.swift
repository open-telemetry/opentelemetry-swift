/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

public class OtlpTraceJsonExporter: SpanExporter {
  
  
  // MARK: - Variables declaration
  private var exportedSpans = [OtlpSpan]()
  private var isRunning: Bool = true
  
  // MARK: - Json Exporter helper methods
  public func getExportedSpans() -> [OtlpSpan] {
    exportedSpans
  }
  
  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    guard isRunning else { return .failure }
    
    let exportRequest = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
      $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
    }
    
    do {
      let jsonData = try exportRequest.jsonUTF8Data()
      do {
        let span = try JSONDecoder().decode(OtlpSpan.self, from: jsonData)
        exportedSpans.append(span)
      } catch {
        print("Decode Error: \(error)")
      }
      return .success
    } catch {
      return .failure
    }
  }
  
  public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    guard isRunning else { return .failure }
    return .success
  }
  
  public func reset() {
    exportedSpans.removeAll()
  }
  
  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    exportedSpans.removeAll()
    isRunning = false
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

/// Main exporter class implementing OTel protocols for Grafana Faro
public final class FaroExporter: SpanExporter, LogRecordExporter {

    private let options: FaroExporterOptions
    private let faroSdk: FaroSdk
    
    static let version = "1.0.0"

    /// Initialize a new Faro exporter instance
    /// - Parameter options: Configuration options
    /// - Throws: FaroExporterError if configuration is invalid
    public init(options: FaroExporterOptions) throws {
        self.options = options
        // Create FaroSdk using factory - this will validate the endpoint configuration
        self.faroSdk = try FaroSdkFactory.getInstance(options: options)
    }

    // MARK: - SpanExporter Implementation
    public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        let body =
              Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
                $0.resourceSpans = SpanAdapter.toProtoResourceSpans(
                  spanDataList: spans)
              }
        print("### bodyJson: \(try? body.jsonString() ?? "nil") ###")
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
        return .success
    }
    
    public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        return .success // TODO: fix real code
    }
    
    // MARK: - Shutdown
    
    public func shutdown() async {
    }
}

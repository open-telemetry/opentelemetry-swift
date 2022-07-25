/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Logging
import GRPC
import NIO
import NIOHPACK
import OpenTelemetryApi
import OpenTelemetrySdk

public class OtlpMetricExporter: MetricExporter {
    let channel: GRPCChannel
    let metricClient: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceClient
    let config : OtlpConfiguration
    var callOptions : CallOptions? = nil



    public init(channel: GRPCChannel, config: OtlpConfiguration = OtlpConfiguration(), logger: Logger = Logger(label: "io.grpc", factory: { _ in SwiftLogNoOpLogHandler() })) {
        self.channel = channel
        self.config = config
        self.metricClient = Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceClient(channel: self.channel)

        if let headers = EnvVarHeaders.attributes {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
        } else if let headers = config.headers {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
        }
        else {
            callOptions = CallOptions(logger: logger)
        }
    }
    
    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        let exportRequest = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
            .with {
                $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: metrics)
            }
        
        if config.timeout > 0 {
            metricClient.defaultCallOptions.timeLimit = TimeLimit.timeout(TimeAmount.nanoseconds(Int64(config.timeout.toNanoseconds)))
        }
        
        let export = metricClient.export(exportRequest, callOptions: callOptions)
        
        do {
            _ = try export.response.wait()
            return .success
        } catch {
            return .failureRetryable
        }
    }
    
    public func flush() -> SpanExporterResultCode {
        return .success
    }
    
    public func shutdown() {
        _ = channel.close()
    }
}

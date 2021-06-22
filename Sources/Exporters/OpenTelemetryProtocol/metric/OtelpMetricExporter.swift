/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import GRPC
import NIO
import NIOHPACK
import OpenTelemetryApi
import OpenTelemetrySdk

public class OtelpMetricExporter: MetricExporter {
    let channel: GRPCChannel
    let metricClient: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceClient
    let timeoutNanos: Int64
     let callOptions : CallOptions? = CallOptions(customMetadata: HPACKHeaders(EnvVarHeaders.attributes))



    public init(channel: GRPCChannel, timeoutNanos: Int64 = 0) {
        self.channel = channel
        self.timeoutNanos = timeoutNanos
        self.metricClient = Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceClient(channel: self.channel)
    }
    
    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        let exportRequest = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
            .with {
                $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: metrics)
            }
        
        if timeoutNanos > 0 {
            metricClient.defaultCallOptions.timeLimit = TimeLimit.timeout(TimeAmount.nanoseconds(timeoutNanos))
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

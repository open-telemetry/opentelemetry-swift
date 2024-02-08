/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import GRPC
import Logging
import NIO
import NIOHPACK
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

public class OtlpMetricExporter: MetricExporter {
    let channel: GRPCChannel
    var metricClient: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceNIOClient
    let config: OtlpConfiguration
    var callOptions: CallOptions?

    public init(channel: GRPCChannel, config: OtlpConfiguration = OtlpConfiguration(), logger: Logging.Logger = Logging.Logger(label: "io.grpc", factory: { _ in SwiftLogNoOpLogHandler() }), envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
        self.channel = channel
        self.config = config
        metricClient = Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceNIOClient(channel: self.channel)
        let userAgentHeader = (Constants.HTTP.userAgent, Headers.getUserAgentHeader())
        if let headers = envVarHeaders {
            var updatedHeaders = headers
            updatedHeaders.append(userAgentHeader)
            callOptions = CallOptions(customMetadata: HPACKHeaders(updatedHeaders), logger: logger)
        } else if let headers = config.headers {
            var updatedHeaders = headers
            updatedHeaders.append(userAgentHeader)
            callOptions = CallOptions(customMetadata: HPACKHeaders(updatedHeaders), logger: logger)
        } else {
            var headers = [(String, String)]()
            headers.append(userAgentHeader)
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
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

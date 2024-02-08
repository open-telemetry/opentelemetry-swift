//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import GRPC
import Logging
import NIO
import NIOHPACK
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

public class StableOtlpMetricExporter: StableMetricExporter {
    public func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
        return aggregationTemporalitySelector.getAggregationTemporality(for: instrument)
    }

    let channel: GRPCChannel
    var metricClient: Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceNIOClient
    let config: OtlpConfiguration
    var callOptions: CallOptions?
    var aggregationTemporalitySelector: AggregationTemporalitySelector
    var defaultAggregationSelector: DefaultAggregationSelector

    public init(channel: GRPCChannel, config: OtlpConfiguration = OtlpConfiguration(), aggregationTemporalitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative(),
                defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance,
                logger: Logging.Logger = Logging.Logger(label: "io.grpc", factory: { _ in SwiftLogNoOpLogHandler() }), envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes)
    {
        self.defaultAggregationSelector = defaultAggregationSelector
        self.aggregationTemporalitySelector = aggregationTemporalitySelector
        self.channel = channel
        self.config = config
        metricClient = Opentelemetry_Proto_Collector_Metrics_V1_MetricsServiceNIOClient(channel: self.channel)
        if let headers = envVarHeaders {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
        } else if let headers = config.headers {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
        } else {
            callOptions = CallOptions(logger: logger)
        }
    }

    public func export(metrics: [OpenTelemetrySdk.StableMetricData]) -> OpenTelemetrySdk.ExportResult {
        let exportRequest = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(stableMetricData: metrics)
        }
        if config.timeout > 0 {
            metricClient.defaultCallOptions.timeLimit = TimeLimit.timeout(TimeAmount.nanoseconds(Int64(config.timeout.toNanoseconds)))
        }
        let export = metricClient.export(exportRequest, callOptions: callOptions)
        do {
            _ = try export.response.wait()
            return .success
        } catch {
            return .failure
        }
    }

    public func flush() -> OpenTelemetrySdk.ExportResult {
        return .success
    }

    public func shutdown() -> OpenTelemetrySdk.ExportResult {
        _ = channel.close()

        return .success
    }
}

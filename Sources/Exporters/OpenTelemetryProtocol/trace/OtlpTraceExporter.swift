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

public class OtlpTraceExporter: SpanExporter {
    let channel: GRPCChannel
    let traceClient: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient
    let config : OtlpConfiguration
    var callOptions : CallOptions? = nil

    public init(channel: GRPCChannel, config: OtlpConfiguration = OtlpConfiguration()) {
        self.channel = channel
        traceClient = Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient(channel: channel)
        self.config = config
        if let headers = EnvVarHeaders.attributes {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers))
        } else if let headers = config.headers {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers))
        }
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        let exportRequest = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }

        if config.timeout > 0 {
            traceClient.defaultCallOptions.timeLimit = TimeLimit.timeout(TimeAmount.nanoseconds(Int64(config.timeout.toNanoseconds)))
        }

        let export = traceClient.export(exportRequest, callOptions: callOptions)

        do {
            // wait() on the response to stop the program from exiting before the response is received.
            _ = try export.response.wait()
            return .success
        } catch {
            return .failure
        }
    }

    public func flush() -> SpanExporterResultCode {
        return .success
    }

    public func shutdown() {
        _ = channel.close()
    }
}

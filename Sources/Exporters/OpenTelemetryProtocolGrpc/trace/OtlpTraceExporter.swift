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
import OpenTelemetryProtocolExporterCommon

public class OtlpTraceExporter: SpanExporter {
    let channel: GRPCChannel
    var traceClient: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceNIOClient
    let config : OtlpConfiguration
    var callOptions : CallOptions? = nil

    public init(channel: GRPCChannel, config: OtlpConfiguration = OtlpConfiguration(), logger: Logging.Logger = Logging.Logger(label: "io.grpc", factory: { _ in SwiftLogNoOpLogHandler() }), envVarHeaders: [(String,String)]? = EnvVarHeaders.attributes) {
        self.channel = channel
        traceClient = Opentelemetry_Proto_Collector_Trace_V1_TraceServiceNIOClient(channel: channel)
        self.config = config
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

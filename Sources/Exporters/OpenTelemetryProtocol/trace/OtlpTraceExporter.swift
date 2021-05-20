/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import GRPC
import NIO
import OpenTelemetryApi
import OpenTelemetrySdk

public class OtlpTraceExporter: SpanExporter {
    let channel: GRPCChannel
    let traceClient: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient
    let timeoutNanos: Int64

    public init(channel: GRPCChannel, timeoutNanos: Int64 = 0) {
        self.channel = channel
        traceClient = Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient(channel: channel)
        self.timeoutNanos = timeoutNanos
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        let exportRequest = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }

        if timeoutNanos > 0 {
            traceClient.defaultCallOptions.timeLimit = TimeLimit.timeout(TimeAmount.nanoseconds(timeoutNanos))
        }

        let export = traceClient.export(exportRequest)

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

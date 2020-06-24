// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import GRPC
import OpenTelemetryApi
import OpenTelemetrySdk

public class OtlpTraceExporter: SpanExporter {
    let channel: GRPCChannel
    let traceClient: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient
    let deadlineMS: Int

    public init(channel: GRPCChannel, deadlineMS: Int = 0) {
        self.channel = channel
        traceClient = Opentelemetry_Proto_Collector_Trace_V1_TraceServiceClient(channel: channel)
        self.deadlineMS = deadlineMS
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        let exportRequest = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }

        if deadlineMS > 0 {
            traceClient.defaultCallOptions.timeout = try! GRPCTimeout.milliseconds(deadlineMS)
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

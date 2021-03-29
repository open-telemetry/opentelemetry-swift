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
import OpenTelemetrySdk

public class OtlpTraceJsonExporter: SpanExporter {
    
    private var exportedSpans = [OtlpSpan]()
    private var isRunning: Bool = true
    
    func getExportedSpans() -> [OtlpSpan] {
        exportedSpans
    }
    
    public func export(spans: [SpanData]) -> SpanExporterResultCode {
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
    
    public func flush() -> SpanExporterResultCode {
        guard isRunning else { return .failure }
        return .success
    }
    
    public func reset() {
        exportedSpans.removeAll()
    }
    
    public func shutdown() {
        exportedSpans.removeAll()
        isRunning = false
    }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetrySdk
import Foundation

public func defaultOltpHttpTracesEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/traces")!
}

public class OtlpHttpTraceExporter: SpanExporter {
    let endpoint: URL
    let urlSession: URLSession
    var pendingSpans: [SpanData] = []
     
    public init(endpoint: URL = defaultOltpHttpTracesEndpoint(), urlSession: URLSession = URLSession.shared) {
        self.endpoint = endpoint
        self.urlSession = urlSession
    }
    
    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        pendingSpans.append(contentsOf: spans)
        return self.flush()
    }

    public func flush() -> SpanExporterResultCode {
        let spans = pendingSpans
        pendingSpans = []
        let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try? body.serializedData()
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error sending telemetry: \(error)")
            }
        }
        
        task.resume()
        
        return .success
    }

    public func shutdown() {
    }
}

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
    private let httpClient: HTTPClient
    var pendingSpans: [SpanData] = []
     
    public init(endpoint: URL = defaultOltpHttpTracesEndpoint()) {
        self.endpoint = endpoint
        self.httpClient = HTTPClient()
    }
    
    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        pendingSpans.append(contentsOf: spans)
        return self.flush()
    }

    public func flush() -> SpanExporterResultCode {
        var exporterResult: SpanExporterResultCode = .success
        let spans = pendingSpans
        pendingSpans = []
        let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try? body.serializedData()
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        
        httpClient.send(request: request) { result in
            switch result {
            case .success(_):
                exporterResult = SpanExporterResultCode.success
            case .failure(let error):
                print(error)
                exporterResult = SpanExporterResultCode.failure
            }
        }
        return exporterResult
    }

    public func shutdown() {
    }
}

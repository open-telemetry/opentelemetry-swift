//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetrySdk
import Foundation

public func defaultOltpHttpTracesEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/traces")!
}

public class OtlpHttpTraceExporter: OtlpHttpExporterBase, SpanExporter {
    var pendingSpans: [SpanData] = []
    
    override
    public init(endpoint: URL = defaultOltpHttpTracesEndpoint(), useSession: URLSession? = nil) {
        super.init(endpoint: endpoint, useSession: useSession)
    }
     
    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        pendingSpans.append(contentsOf: spans)
        return self.flush()
    }

    public func flush() -> SpanExporterResultCode {
        var exporterResult: SpanExporterResultCode = .failure
        let spans = pendingSpans
        pendingSpans = []
        let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }
        
        let request = createRequest(body: body, endpoint: endpoint)
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
}

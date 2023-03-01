//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetrySdk
import Foundation

public func defaultOltpHTTPMetricsEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/metrics")!
}

public class OtlpHttpMetricExporter: MetricExporter {
    let endpoint: URL
    private let httpClient: HTTPClient
    var pendingMetrics: [Metric] = []
    
    public init(endpoint: URL = defaultOltpHTTPMetricsEndpoint(), useSession: URLSession? = nil) {
        self.endpoint = endpoint
        if let providedSession = useSession {
            self.httpClient = HTTPClient(session: providedSession)
        } else {
            self.httpClient = HTTPClient()
        }
    }
    
    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        pendingMetrics.append(contentsOf: metrics)
        return self.flush()
    }

    public func flush() -> MetricExporterResultCode {
        var exporterResult: MetricExporterResultCode = .success

        let metrics = pendingMetrics
        pendingMetrics = []
        let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
            .with {
                $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: metrics)
            }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try? body.serializedData()
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        
        httpClient.send(request: request) { result in
            switch result {
            case .success(_):
                exporterResult = MetricExporterResultCode.success
            case .failure(let error):
                print("ERROR: \(error)")
                exporterResult = MetricExporterResultCode.failureNotRetryable // FIXME how do I know what type of failure?
            }
        }
        return exporterResult
    }
    
    
    public func shutdown() {
        
    }
}

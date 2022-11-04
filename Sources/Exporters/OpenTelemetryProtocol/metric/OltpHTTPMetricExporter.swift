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
    let urlSession: URLSession
    var pendingMetrics: [Metric] = []
    
    public init(endpoint: URL = defaultOltpHTTPMetricsEndpoint(), urlSession: URLSession = URLSession.shared) {
        self.endpoint = endpoint
        self.urlSession = urlSession
    }
    
    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        pendingMetrics.append(contentsOf: metrics)
        return self.flush()
    }

    public func flush() -> MetricExporterResultCode {
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

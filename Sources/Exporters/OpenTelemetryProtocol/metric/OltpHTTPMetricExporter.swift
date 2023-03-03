//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetrySdk
import Foundation

public func defaultOltpHTTPMetricsEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/metrics")!
}

public class OtlpHttpMetricExporter: OtlpHttpExporterBase, MetricExporter {
    var pendingMetrics: [Metric] = []
    
    override
    public init(endpoint: URL = defaultOltpHTTPMetricsEndpoint(), useSession: URLSession? = nil) {
        super.init(endpoint: endpoint, useSession: useSession)
    }
    
    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        pendingMetrics.append(contentsOf: metrics)
        let sendingMetrics = pendingMetrics
        pendingMetrics = []
        let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: sendingMetrics)
        }

        let request = createRequest(body: body, endpoint: endpoint)
        httpClient.send(request: request) { [weak self] result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                self?.pendingMetrics.append(contentsOf: sendingMetrics)
                print(error)
            }
        }
        
        return .success
    }

    public func flush() -> MetricExporterResultCode {
        var exporterResult: MetricExporterResultCode = .success

        if !pendingMetrics.isEmpty {
            let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
                $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: pendingMetrics)
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            let request = createRequest(body: body, endpoint: endpoint)
            httpClient.send(request: request) { result in
                switch result {
                case .success(_):
                    break
                case .failure(let error):
                    print(error)
                    exporterResult = MetricExporterResultCode.failureNotRetryable
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
        return exporterResult
    }
}

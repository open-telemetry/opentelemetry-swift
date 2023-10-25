//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon
import Foundation

public func defaultOltpHTTPMetricsEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/metrics")!
}

public class OtlpHttpMetricExporter: OtlpHttpExporterBase, MetricExporter {
  var pendingMetrics: [Metric] = []
  let dispatchQueue = DispatchQueue(label: "OtlpHttpMetricExporter Queue")

  override
  public init(endpoint: URL = defaultOltpHTTPMetricsEndpoint(), config : OtlpConfiguration = OtlpConfiguration(), useSession: URLSession? = nil, envVarHeaders: [(String,String)]? = EnvVarHeaders.attributes) {
    super.init(endpoint: endpoint, config: config, useSession: useSession, envVarHeaders: envVarHeaders)
  }
  
  public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
    var sendingMetrics: [Metric]!
    dispatchQueue.sync {
      pendingMetrics.append(contentsOf: metrics)
      sendingMetrics = pendingMetrics
      pendingMetrics = []
    }
    
    let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
      $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: sendingMetrics)
    }
    
    let request = createRequest(body: body, endpoint: endpoint)
    httpClient.send(request: request) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(_):
        break
      case .failure(let error):
        self.dispatchQueue.sync { [weak self] in
          self?.pendingMetrics.append(contentsOf: sendingMetrics)
        }
        print(error)
      }
    }
    
    return .success
  }
  
  public func flush() -> MetricExporterResultCode {
    var exporterResult: MetricExporterResultCode = .success
    var pendingMetrics: [Metric]!
    dispatchQueue.sync {
      pendingMetrics = self.pendingMetrics
    }
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

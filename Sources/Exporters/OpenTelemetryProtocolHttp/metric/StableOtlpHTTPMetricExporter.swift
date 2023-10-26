//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

public func defaultStableOtlpHTTPMetricsEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/metrics")!
}

public class StableOtlpHTTPMetricExporter: StableOtlpHTTPExporterBase, StableMetricExporter {
  var aggregationTemporalitySelector: AggregationTemporalitySelector
  var defaultAggregationSelector: DefaultAggregationSelector
  
  var pendingMetrics: [StableMetricData] = []
  
  // MARK: - Init
  
  public init(endpoint: URL, config: OtlpConfiguration = OtlpConfiguration(), aggregationTemporalitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative(), defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance, useSession: URLSession? = nil, envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    
    self.aggregationTemporalitySelector = aggregationTemporalitySelector
    self.defaultAggregationSelector = defaultAggregationSelector
    
    super.init(endpoint: endpoint, config: config, useSession: useSession, envVarHeaders: envVarHeaders)
  }
  
  
  // MARK: - StableMetricsExporter
  
  public func export(metrics : [StableMetricData]) -> ExportResult {
    pendingMetrics.append(contentsOf: metrics)
    let sendingMetrics = pendingMetrics
    pendingMetrics = []
    let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
      $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(stableMetricData: sendingMetrics)
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
  
  public func flush() -> ExportResult {
    var exporterResult: ExportResult = .success
    
    if !pendingMetrics.isEmpty {
      let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
        $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(stableMetricData: pendingMetrics)
      }
      let semaphore = DispatchSemaphore(value: 0)
      let request = createRequest(body: body, endpoint: endpoint)
      httpClient.send(request: request) { result in
        switch result {
        case .success(_):
          break
        case .failure(let error):
          print(error)
          exporterResult = .failure
        }
        semaphore.signal()
      }
      semaphore.wait()
    }
    
    return exporterResult
  }
  
  public func shutdown() -> ExportResult {
    return .success
  }
  
  // MARK: - AggregationTemporalitySelectorProtocol
  
  public func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    return aggregationTemporalitySelector.getAggregationTemporality(for: instrument)
  }
  
  // MARK: - DefaultAggregationSelector
  
  public func getDefaultAggregation(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.Aggregation {
    return defaultAggregationSelector.getDefaultAggregation(for: instrument)
  }
}

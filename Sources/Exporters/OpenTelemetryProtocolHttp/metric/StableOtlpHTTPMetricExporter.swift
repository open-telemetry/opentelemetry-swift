//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public func defaultStableOtlpHTTPMetricsEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/metrics")!
}

public class StableOtlpHTTPMetricExporter: StableOtlpHTTPExporterBase, StableMetricExporter {
  var aggregationTemporalitySelector: AggregationTemporalitySelector
  var defaultAggregationSelector: DefaultAggregationSelector

  var pendingMetrics: [StableMetricData] = []
  private let exporterLock = Lock()
  private var exporterMetrics: ExporterMetrics?

  // MARK: - Init

  public init(endpoint: URL, config: OtlpConfiguration = OtlpConfiguration(),
              aggregationTemporalitySelector: AggregationTemporalitySelector =
                AggregationTemporality.alwaysCumulative(),
              defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance,
              useSession: URLSession? = nil,
              envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.aggregationTemporalitySelector = aggregationTemporalitySelector
    self.defaultAggregationSelector = defaultAggregationSelector

    super.init(endpoint: endpoint, config: config, useSession: useSession,
               envVarHeaders: envVarHeaders)
  }

  /// A `convenience` constructor to provide support for exporter metric using`StableMeterProvider` type
  /// - Parameters:
  ///    - endpoint: Exporter endpoint injected as dependency
  ///    - config: Exporter configuration including type of exporter
  ///    - meterProvider: Injected `StableMeterProvider` for metric
  ///    - aggregationTemporalitySelector: aggregator
  ///    - defaultAggregationSelector: default aggregator
  ///    - useSession: Overridden `URLSession` if any
  ///    - envVarHeaders: Extra header key-values
  convenience public init(endpoint: URL,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          meterProvider: StableMeterProvider,
                          aggregationTemporalitySelector: AggregationTemporalitySelector =
                            AggregationTemporality.alwaysCumulative(),
                          defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector
                            .instance,
                          useSession: URLSession? = nil,
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(endpoint: endpoint,
              config: config,
              aggregationTemporalitySelector: aggregationTemporalitySelector,
              defaultAggregationSelector: defaultAggregationSelector,
              useSession: useSession,
              envVarHeaders: envVarHeaders)
    exporterMetrics = ExporterMetrics(type: "metric",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  // MARK: - StableMetricsExporter

  public func export(metrics: [StableMetricData]) -> ExportResult {
    var sendingMetrics: [StableMetricData] = []
    exporterLock.withLockVoid {
      pendingMetrics.append(contentsOf: metrics)
      sendingMetrics = pendingMetrics
      pendingMetrics = []
    }
    let body =
      Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
        $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
          stableMetricData: sendingMetrics)
      }
    exporterMetrics?.addSeen(value: sendingMetrics.count)
    var request = createRequest(body: body, endpoint: endpoint)
    request.timeoutInterval = min(TimeInterval.greatestFiniteMagnitude, config.timeout)
    httpClient.send(request: request) { [weak self] result in
      switch result {
      case .success:
        self?.exporterMetrics?.addSuccess(value: sendingMetrics.count)
      case .failure(let error):
        self?.exporterMetrics?.addFailed(value: sendingMetrics.count)
        self?.exporterLock.withLockVoid {
          self?.pendingMetrics.append(contentsOf: sendingMetrics)
        }
        print(error)
      }
    }

    return .success
  }

  public func flush() -> ExportResult {
    var exporterResult: ExportResult = .success
    var pendingMetrics: [StableMetricData] = []
    exporterLock.withLockVoid {
      pendingMetrics = self.pendingMetrics
    }
    if !pendingMetrics.isEmpty {
      let body =
        Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
          .with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
              stableMetricData: pendingMetrics)
          }
      let semaphore = DispatchSemaphore(value: 0)
      var request = createRequest(body: body, endpoint: endpoint)
      request.timeoutInterval = min(TimeInterval.greatestFiniteMagnitude, config.timeout)
      httpClient.send(request: request) { [weak self] result in
        switch result {
        case .success:
          self?.exporterMetrics?.addSuccess(value: pendingMetrics.count)
        case .failure(let error):
          self?.exporterMetrics?.addFailed(value: pendingMetrics.count)
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

  public func getAggregationTemporality(
    for instrument: OpenTelemetrySdk.InstrumentType
  ) -> OpenTelemetrySdk.AggregationTemporality {
    return aggregationTemporalitySelector.getAggregationTemporality(
      for: instrument)
  }

  // MARK: - DefaultAggregationSelector

  public func getDefaultAggregation(
    for instrument: OpenTelemetrySdk.InstrumentType
  ) -> OpenTelemetrySdk.Aggregation {
    return defaultAggregationSelector.getDefaultAggregation(for: instrument)
  }
}

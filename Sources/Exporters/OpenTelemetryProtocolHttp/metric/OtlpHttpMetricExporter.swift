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

public func defaultOtlpHttpMetricsEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/metrics")!
}

@available(*, deprecated, renamed: "defaultOtlpHttpMetricsEndpoint")
public func defaultStableOtlpHTTPMetricsEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/metrics")!
}

@available(*, deprecated, renamed: "OtlpHttpMetricExporter")
public typealias StableOtlpHTTPMetricExporter = OtlpHttpMetricExporter

@available(*, deprecated, renamed: "OtlpHttpMetricExporter")
public typealias OtlpHTTPMetricExporter = OtlpHttpMetricExporter

public final class OtlpHttpMetricExporter: MetricExporter, @unchecked Sendable {
  var aggregationTemporalitySelector: AggregationTemporalitySelector
  var defaultAggregationSelector: DefaultAggregationSelector

  private let base: OtlpHttpExporterBase<MetricData>
  private var exporterMetrics: ExporterMetrics?

  // MARK: - Init

  init(base: OtlpHttpExporterBase<MetricData>,
       aggregationTemporalitySelector: AggregationTemporalitySelector,
       defaultAggregationSelector: DefaultAggregationSelector) {
    self.base = base
    self.aggregationTemporalitySelector = aggregationTemporalitySelector
    self.defaultAggregationSelector = defaultAggregationSelector
  }

  public convenience init(endpoint: URL,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          aggregationTemporalitySelector: AggregationTemporalitySelector =
                          AggregationTemporality.alwaysCumulative(),
                          defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance,
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
                          requeueOnFailure: Bool = true) {
    self.init(base: OtlpHttpExporterBase(endpoint: endpoint,
                                         config: config,
                                         httpClient: httpClient,
                                         envVarHeaders: envVarHeaders,
                                         requeueOnFailure: requeueOnFailure),
              aggregationTemporalitySelector: aggregationTemporalitySelector,
              defaultAggregationSelector: defaultAggregationSelector)
  }

  /// A `convenience` constructor to provide support for exporter metric using`StableMeterProvider` type
  /// - Parameters:
  ///    - endpoint: Exporter endpoint injected as dependency
  ///    - config: Exporter configuration including type of exporter
  ///    - meterProvider: Injected `StableMeterProvider` for metric
  ///    - aggregationTemporalitySelector: aggregator
  ///    - defaultAggregationSelector: default aggregator
  ///    - httpClient: Custom HTTPClient implementation
  ///    - envVarHeaders: Extra header key-values
  ///    - requeueOnFailure: Re-append failed batches to the in-memory pending queue
  public convenience init(endpoint: URL,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          meterProvider: any MeterProvider,
                          aggregationTemporalitySelector: AggregationTemporalitySelector =
                            AggregationTemporality.alwaysCumulative(),
                          defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector
                            .instance,
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
                          requeueOnFailure: Bool = true) {
    self.init(endpoint: endpoint,
              config: config,
              aggregationTemporalitySelector: aggregationTemporalitySelector,
              defaultAggregationSelector: defaultAggregationSelector,
              httpClient: httpClient,
              envVarHeaders: envVarHeaders,
              requeueOnFailure: requeueOnFailure)
    exporterMetrics = ExporterMetrics(type: "metric",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  // MARK: - StableMetricsExporter

  public func export(metrics: [MetricData]) -> ExportResult {
    let sendingMetrics = base.drainPending(adding: metrics)
    let body =
      Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
        $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
          metricData: sendingMetrics)
      }
    exporterMetrics?.addSeen(value: sendingMetrics.count)
    var request = base.createRequest(body: body, endpoint: base.endpoint)
    request.timeoutInterval = min(TimeInterval.greatestFiniteMagnitude, base.config.timeout)
    base.httpClient.send(request: request) { [weak self] result in
      switch result {
      case .success:
        self?.exporterMetrics?.addSuccess(value: sendingMetrics.count)
      case let .failure(error):
        self?.exporterMetrics?.addFailed(value: sendingMetrics.count)
        self?.base.requeue(sendingMetrics)
        OpenTelemetry.instance.feedbackHandler?("\(error)")
      }
    }

    return .success
  }

  public func flush() -> ExportResult {
    var exporterResult: ExportResult = .success
    let pendingMetrics = base.snapshotPending()
    if !pendingMetrics.isEmpty {
      let sentCount = pendingMetrics.count
      let body =
        Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
          .with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
              metricData: pendingMetrics)
          }
      let semaphore = DispatchSemaphore(value: 0)
      var request = base.createRequest(body: body, endpoint: base.endpoint)
      let timeout = min(TimeInterval.greatestFiniteMagnitude, base.config.timeout)
      request.timeoutInterval = timeout
      base.httpClient.send(request: request) { [weak self] result in
        switch result {
        case .success:
          self?.exporterMetrics?.addSuccess(value: sentCount)
          self?.base.dropFlushed(count: sentCount)
        case let .failure(error):
          self?.exporterMetrics?.addFailed(value: sentCount)
          OpenTelemetry.instance.feedbackHandler?("\(error)")
          exporterResult = .failure
        }
        semaphore.signal()
      }

      let waitResult = semaphore.wait(timeout: .now() + timeout)
      if waitResult == .timedOut {
        exporterMetrics?.addFailed(value: sentCount)
        return .failure
      }
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

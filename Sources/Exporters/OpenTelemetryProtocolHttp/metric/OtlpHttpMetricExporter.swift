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

public class OtlpHttpMetricExporter: OtlpHttpExporterBase, MetricExporter, @unchecked Sendable {
  var aggregationTemporalitySelector: AggregationTemporalitySelector
  var defaultAggregationSelector: DefaultAggregationSelector

  private let pendingQueue = PendingQueue<MetricData>()
  var pendingMetrics: [MetricData] {
    pendingQueue.snapshot()
  }
  private var exporterMetrics: ExporterMetrics?

  // MARK: - Init

  public init(endpoint: URL, config: OtlpConfiguration = OtlpConfiguration(),
              aggregationTemporalitySelector: AggregationTemporalitySelector =
                AggregationTemporality.alwaysCumulative(),
              defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance,
              httpClient: HTTPClient = BaseHTTPClient(),
              envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.aggregationTemporalitySelector = aggregationTemporalitySelector
    self.defaultAggregationSelector = defaultAggregationSelector

    super.init(endpoint: endpoint, config: config, httpClient: httpClient,
               envVarHeaders: envVarHeaders)
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
  public convenience init(endpoint: URL,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          meterProvider: any MeterProvider,
                          aggregationTemporalitySelector: AggregationTemporalitySelector =
                            AggregationTemporality.alwaysCumulative(),
                          defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector
                            .instance,
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(endpoint: endpoint,
              config: config,
              aggregationTemporalitySelector: aggregationTemporalitySelector,
              defaultAggregationSelector: defaultAggregationSelector,
              httpClient: httpClient,
              envVarHeaders: envVarHeaders)
    exporterMetrics = ExporterMetrics(type: "metric",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  // MARK: - StableMetricsExporter

  public func export(metrics: [MetricData]) -> ExportResult {
    let timeout = min(TimeInterval.greatestFiniteMagnitude, config.timeout)
    let estimatedCount = metrics.count + pendingQueue.snapshot().count
    return waitSynchronously(timeout: timeout) {
      await self.export(metrics: metrics)
    } ?? {
      exporterMetrics?.addFailed(value: estimatedCount)
      return .failure
    }()
  }

  public func export(metrics: [MetricData]) async -> ExportResult {
    let batch = pendingQueue.enqueueAndTakeAll(metrics)
    let timeout = min(TimeInterval.greatestFiniteMagnitude, config.timeout)
    return await sendBatch(batch, timeout: timeout, isFlush: false)
  }

  public func flush() -> ExportResult {
    let timeout = min(TimeInterval.greatestFiniteMagnitude, config.timeout)
    let pendingCount = pendingQueue.snapshot().count
    return waitSynchronously(timeout: timeout) {
      await self.flush()
    } ?? {
      exporterMetrics?.addFailed(value: pendingCount)
      return .failure
    }()
  }

  public func flush() async -> ExportResult {
    let pending = pendingQueue.snapshot()
    guard !pending.isEmpty else { return .success }
    let timeout = min(TimeInterval.greatestFiniteMagnitude, config.timeout)
    let result = await sendBatch(pending, timeout: timeout, isFlush: true)
    if case .success = result {
      pendingQueue.dropPrefix(pending.count)
    }
    return result
  }

  public func shutdown() -> ExportResult {
    return .success
  }

  public func shutdown() async -> ExportResult {
    .success
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

  private func sendBatch(_ batch: [MetricData],
                         timeout: TimeInterval,
                         isFlush: Bool) async -> ExportResult {
    let body =
      Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
        .with {
          $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
            metricData: batch)
        }
    var request = createRequest(body: body, endpoint: endpoint)
    request.timeoutInterval = timeout
    if !isFlush {
      exporterMetrics?.addSeen(value: batch.count)
    }

    let sendResult = await sendWithTimeout(httpClient: httpClient, timeout: timeout, request: request)
    switch sendResult {
    case .success:
      exporterMetrics?.addSuccess(value: batch.count)
      return .success
    case let .failure(error):
      exporterMetrics?.addFailed(value: batch.count)
      if !isFlush, !(error is OtlpHttpExportTimeoutError) {
        pendingQueue.requeue(batch)
      }
      if !(error is OtlpHttpExportTimeoutError) {
        OpenTelemetry.instance.feedbackHandler?("\(error)")
      }
      return .failure
    }
  }
}

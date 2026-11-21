//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

#if OTLPGRPC

import Foundation
import GRPCCore
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public final class OtlpMetricExporter: MetricExporter, Sendable {
  let config: OtlpConfiguration
  let envVarHeaders: [(String, String)]?
  let aggregationTemporalitySelector: AggregationTemporalitySelector
  let defaultAggregationSelector: DefaultAggregationSelector
  let connection: OtlpGrpcConnection
  private let metricClient: any OtlpGrpcServiceClient<
    Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest,
    Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse
  >

  init(client: GRPCClient<some ClientTransport>,
       ownsClient: Bool,
       config: OtlpConfiguration,
       aggregationTemporalitySelector: AggregationTemporalitySelector,
       defaultAggregationSelector: DefaultAggregationSelector,
       envVarHeaders: [(String, String)]?) {
    self.config = config
    self.envVarHeaders = envVarHeaders
    self.aggregationTemporalitySelector = aggregationTemporalitySelector
    self.defaultAggregationSelector = defaultAggregationSelector
    connection = OtlpGrpcConnection(client: client, ownsClient: ownsClient)
    metricClient = Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.Client(wrapping: client)
  }

  /// Creates an exporter that sends metrics through a client you manage.
  ///
  /// You run the client, so shutting down the exporter doesn't stop it: the exporter only
  /// stops sending. Call `runConnections()` on the client before exporting, and stop it
  /// yourself once you no longer need it.
  ///
  /// Compression only applies if the client's transport enables the algorithm.
  /// - Parameters:
  ///   - client: The gRPC client to send metrics through.
  ///   - config: Exporter configuration.
  ///   - aggregationTemporalitySelector: Selects the aggregation temporality per instrument type.
  ///   - defaultAggregationSelector: Selects the default aggregation per instrument type.
  ///   - envVarHeaders: Extra header key-values. They replace the configuration's headers.
  public convenience init(client: GRPCClient<some ClientTransport>,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          aggregationTemporalitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative(),
                          defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance,
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(client: client,
              ownsClient: false,
              config: config,
              aggregationTemporalitySelector: aggregationTemporalitySelector,
              defaultAggregationSelector: defaultAggregationSelector,
              envVarHeaders: envVarHeaders)
  }

  /// Creates an exporter that owns its gRPC client.
  ///
  /// The exporter runs the client's connections and stops them when it shuts down.
  ///
  /// Compression only applies if the transport enables the algorithm.
  /// - Parameters:
  ///   - transport: The transport to send metrics over.
  ///   - config: Exporter configuration.
  ///   - aggregationTemporalitySelector: Selects the aggregation temporality per instrument type.
  ///   - defaultAggregationSelector: Selects the default aggregation per instrument type.
  ///   - envVarHeaders: Extra header key-values. They replace the configuration's headers.
  public convenience init(transport: some ClientTransport,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          aggregationTemporalitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative(),
                          defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance,
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(client: GRPCClient(transport: transport),
              ownsClient: true,
              config: config,
              aggregationTemporalitySelector: aggregationTemporalitySelector,
              defaultAggregationSelector: defaultAggregationSelector,
              envVarHeaders: envVarHeaders)
  }

  public func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    aggregationTemporalitySelector.getAggregationTemporality(for: instrument)
  }

  /// Blocks the calling thread until the export finishes.
  ///
  /// Don't call this from Swift concurrency. Use the async overload instead.
  public func export(metrics: [MetricData]) -> ExportResult {
    otlpGrpcBlocking { await self.export(metrics: metrics) }
  }

  public func export(metrics: [MetricData]) async -> ExportResult {
    guard !connection.isShutdown else {
      return .failure
    }
    let exportRequest = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
      $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricData: metrics)
    }
    let metadata = makeOtlpGrpcMetadata(config: config, envVarHeaders: envVarHeaders)
    let options = makeOtlpGrpcCallOptions(config: config, explicitTimeout: nil)
    do {
      _ = try await metricClient.export(exportRequest, metadata: metadata, options: options)
      return .success
    } catch {
      OpenTelemetry.instance.feedbackHandler?("OTLP metric export failed: \(error)")
      return .failure
    }
  }

  public func flush() -> ExportResult {
    .success
  }

  public func flush() async -> ExportResult {
    .success
  }

  public func shutdown() -> ExportResult {
    connection.shutdown()
    return .success
  }

  public func shutdown() async -> ExportResult {
    await connection.shutdown(timeout: nil)
    return .success
  }
}

#endif

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public final class OtlpLogExporter: LogRecordExporter, Sendable {
  let config: OtlpConfiguration
  let envVarHeaders: [(String, String)]?
  let connection: OtlpGrpcConnection
  private let logClient: any OtlpGrpcServiceClient<
    Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest,
    Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse
  >

  init(client: GRPCClient<some ClientTransport>,
       ownsClient: Bool,
       config: OtlpConfiguration,
       envVarHeaders: [(String, String)]?) {
    self.config = config
    self.envVarHeaders = envVarHeaders
    connection = OtlpGrpcConnection(client: client, ownsClient: ownsClient)
    logClient = Opentelemetry_Proto_Collector_Logs_V1_LogsService.Client(wrapping: client)
  }

  /// Creates an exporter that sends log records through a client you manage.
  ///
  /// You run the client, so shutting down the exporter doesn't stop it: the exporter only
  /// stops sending. Call `runConnections()` on the client before exporting, and stop it
  /// yourself once you no longer need it.
  ///
  /// Compression only applies if the client's transport enables the algorithm.
  /// - Parameters:
  ///   - client: The gRPC client to send log records through.
  ///   - config: Exporter configuration.
  ///   - envVarHeaders: Extra header key-values. They replace the configuration's headers.
  public convenience init(client: GRPCClient<some ClientTransport>,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(client: client, ownsClient: false, config: config, envVarHeaders: envVarHeaders)
  }

  /// Creates an exporter that owns its gRPC client.
  ///
  /// The exporter runs the client's connections and stops them when it shuts down.
  ///
  /// Compression only applies if the transport enables the algorithm.
  /// - Parameters:
  ///   - transport: The transport to send log records over.
  ///   - config: Exporter configuration.
  ///   - envVarHeaders: Extra header key-values. They replace the configuration's headers.
  public convenience init(transport: some ClientTransport,
                          config: OtlpConfiguration = OtlpConfiguration(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(client: GRPCClient(transport: transport),
              ownsClient: true,
              config: config,
              envVarHeaders: envVarHeaders)
  }

  /// Blocks the calling thread until the export finishes.
  ///
  /// Calling this from Swift concurrency doesn't deadlock the cooperative thread pool, but it still
  /// blocks a cooperative thread for the whole export, so prefer the async overload there.
  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> ExportResult {
    otlpGrpcBlocking(timeout: otlpGrpcExportTimeout(config: config, explicitTimeout: explicitTimeout),
                     whenCalledFromExecutor: .failure) {
      await self.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }
  }

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) async -> ExportResult {
    guard !connection.isShutdown else {
      return .failure
    }
    let logRequest = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
      request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
    }
    let metadata = makeOtlpGrpcMetadata(config: config, envVarHeaders: envVarHeaders)
    let options = makeOtlpGrpcCallOptions(config: config, explicitTimeout: explicitTimeout)
    do {
      _ = try await logClient.export(logRequest, metadata: metadata, options: options)
      return .success
    } catch {
      OpenTelemetry.instance.feedbackHandler?("OTLP log export failed: \(error)")
      return .failure
    }
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    connection.shutdown()
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) async {
    await connection.shutdown(timeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    .success
  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) async -> ExportResult {
    .success
  }
}

#endif

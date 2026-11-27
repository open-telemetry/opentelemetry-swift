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
public final class OtlpTraceExporter: SpanExporter, Sendable {
  let config: OtlpConfiguration
  let envVarHeaders: [(String, String)]?
  let connection: OtlpGrpcConnection
  private let traceClient: any OtlpGrpcServiceClient<
    Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest,
    Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse
  >

  init(client: GRPCClient<some ClientTransport>,
       ownsClient: Bool,
       config: OtlpConfiguration,
       envVarHeaders: [(String, String)]?) {
    self.config = config
    self.envVarHeaders = envVarHeaders
    connection = OtlpGrpcConnection(client: client, ownsClient: ownsClient)
    traceClient = Opentelemetry_Proto_Collector_Trace_V1_TraceService.Client(wrapping: client)
  }

  /// Creates an exporter that sends spans through a client you manage.
  ///
  /// You run the client, so shutting down the exporter doesn't stop it: the exporter only
  /// stops sending. Call `runConnections()` on the client before exporting, and stop it
  /// yourself once you no longer need it.
  ///
  /// Compression only applies if the client's transport enables the algorithm.
  /// - Parameters:
  ///   - client: The gRPC client to send spans through.
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
  ///   - transport: The transport to send spans over.
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
  /// When the exporter owns its client, calling this from Swift concurrency doesn't deadlock the
  /// cooperative thread pool, but it still blocks a cooperative thread for the whole export, so
  /// prefer the async overload there. A client you run yourself only connects where you run
  /// `runConnections()`. If that's the cooperative pool and blocked callers saturate it, exports
  /// fail at their timeout, or hang without one.
  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    let metadata = makeOtlpGrpcMetadata(config: config, envVarHeaders: envVarHeaders)
    return otlpGrpcBlocking(timeout: otlpGrpcExportTimeout(config: config, explicitTimeout: explicitTimeout),
                            whenCalledFromExecutor: .failure) {
      await self.export(spans: spans, explicitTimeout: explicitTimeout, metadata: metadata)
    }
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) async -> SpanExporterResultCode {
    await export(spans: spans,
                 explicitTimeout: explicitTimeout,
                 metadata: makeOtlpGrpcMetadata(config: config, envVarHeaders: envVarHeaders))
  }

  private func export(spans: [SpanData],
                      explicitTimeout: TimeInterval?,
                      metadata: Metadata) async -> SpanExporterResultCode {
    guard !connection.isShutdown else {
      return .failure
    }
    let exportRequest = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
      $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
    }
    let options = makeOtlpGrpcCallOptions(config: config, explicitTimeout: explicitTimeout)
    do {
      let response = try await traceClient.export(exportRequest, metadata: metadata, options: options)
      if response.hasPartialSuccess {
        reportPartialSuccess(response.partialSuccess)
      }
      // OTLP partial-success responses must not be retried.
      return .success
    } catch {
      OpenTelemetry.instance.feedbackHandler?("OTLP trace export failed: \(error)")
      return .failure
    }
  }

  public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    return .success
  }

  public func flush(explicitTimeout: TimeInterval? = nil) async -> SpanExporterResultCode {
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    connection.shutdown()
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) async {
    await connection.shutdown(timeout: explicitTimeout)
  }

  private func reportPartialSuccess(
    _ partialSuccess: Opentelemetry_Proto_Collector_Trace_V1_ExportTracePartialSuccess
  ) {
    let rejectedSpans = partialSuccess.rejectedSpans
    let errorMessage = partialSuccess.errorMessage
    guard rejectedSpans != 0 || !errorMessage.isEmpty else {
      return
    }

    var details = "rejected_spans=\(rejectedSpans)"
    if !errorMessage.isEmpty {
      details += ", error_message=\(errorMessage)"
    }

    if rejectedSpans != 0 {
      OpenTelemetry.instance.feedbackHandler?("OTLP trace export partially succeeded: \(details)")
    } else {
      OpenTelemetry.instance.feedbackHandler?("OTLP trace export succeeded with a warning: \(details)")
    }
  }
}

#endif

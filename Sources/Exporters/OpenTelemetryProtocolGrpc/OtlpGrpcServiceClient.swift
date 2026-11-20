/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import GRPCCore
import OpenTelemetryProtocolExporterCommon

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
protocol OtlpGrpcServiceClient<Request, Response>: Sendable {
  associatedtype Request: Sendable
  associatedtype Response: Sendable

  func export(_ request: Request, metadata: Metadata, options: CallOptions) async throws -> Response
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension Opentelemetry_Proto_Collector_Trace_V1_TraceService.Client: OtlpGrpcServiceClient {
  func export(
    _ request: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest,
    metadata: Metadata,
    options: CallOptions
  ) async throws -> Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse {
    try await export(request, metadata: metadata, options: options, onResponse: { try $0.message })
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.Client: OtlpGrpcServiceClient {
  func export(
    _ request: Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest,
    metadata: Metadata,
    options: CallOptions
  ) async throws -> Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse {
    try await export(request, metadata: metadata, options: options, onResponse: { try $0.message })
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension Opentelemetry_Proto_Collector_Logs_V1_LogsService.Client: OtlpGrpcServiceClient {
  func export(
    _ request: Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest,
    metadata: Metadata,
    options: CallOptions
  ) async throws -> Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse {
    try await export(request, metadata: metadata, options: options, onResponse: { try $0.message })
  }
}

#endif

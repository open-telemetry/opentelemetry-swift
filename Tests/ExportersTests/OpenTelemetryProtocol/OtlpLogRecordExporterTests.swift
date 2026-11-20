/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetrySdk
import Synchronization
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class OtlpLogRecordExporterTests: XCTestCase {
  let traceIdBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4]
  let spanIdBytes: [UInt8] = [0, 0, 0, 0, 4, 3, 2, 1]
  var traceId: TraceId!
  var spanId: SpanId!
  let tracestate = TraceState()
  var spanContext: SpanContext!

  var fakeCollector: FakeLogCollector!
  var server: OtlpGrpcTestServer<FakeLogCollector>!

  override func setUp() async throws {
    fakeCollector = FakeLogCollector()
    server = try await OtlpGrpcTestServer(service: fakeCollector)
    traceId = TraceId(fromBytes: traceIdBytes)
    spanId = SpanId(fromBytes: spanIdBytes)
    spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: tracestate)
  }

  override func tearDown() async throws {
    await server.stop()
  }

  private func makeExporter(
    config: OtlpConfiguration = OtlpConfiguration(),
    envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes
  ) throws -> OtlpLogExporter {
    try OtlpLogExporter(
      transport: server.makeClientTransport(),
      config: config,
      envVarHeaders: envVarHeaders
    )
  }

  private func makeLogRecord(severity: Severity = .fatal, body: String = "Hello, world") -> ReadableLogRecord {
    ReadableLogRecord(resource: Resource(),
                      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                      timestamp: Date(),
                      observedTimestamp: Date.distantPast,
                      spanContext: spanContext,
                      severity: severity,
                      body: AttributeValue.string(body),
                      attributes: ["event.name": AttributeValue.string("name"), "event.domain": AttributeValue.string("domain")])
  }

  func testExport() throws {
    let logRecord = makeLogRecord()

    let exporter = try makeExporter()
    let result = exporter.export(logRecords: [logRecord])
    XCTAssertEqual(result, ExportResult.success)
    XCTAssertEqual(fakeCollector.receivedLogs, LogRecordAdapter.toProtoResourceRecordLog(logRecordList: [logRecord]))
    exporter.shutdown()
  }

  func testConfigHeadersIsNil_whenDefaultInitCalled() throws {
    let exporter = try makeExporter()
    defer { exporter.shutdown() }
    XCTAssertNil(exporter.config.headers)

    XCTAssertEqual(exporter.export(logRecords: [makeLogRecord()]), .success)
    XCTAssertEqual(fakeCollector.receivedUserAgentHeaders, [Headers.getUserAgentHeader()])
  }

  func testConfigHeadersAreSet_whenInitCalledWithCustomConfig() throws {
    let config = OtlpConfiguration(timeout: TimeInterval(10), headers: [("FOO", "BAR")])
    let exporter = try makeExporter(config: config, envVarHeaders: nil)
    defer { exporter.shutdown() }
    XCTAssertNotNil(exporter.config.headers)
    XCTAssertEqual(exporter.config.headers?[0].0, "FOO")
    XCTAssertEqual(exporter.config.headers?[0].1, "BAR")

    XCTAssertEqual(exporter.export(logRecords: [makeLogRecord()]), .success)
    XCTAssertEqual(fakeCollector.receivedHeaders("FOO"), ["BAR"])
    XCTAssertEqual(fakeCollector.receivedUserAgentHeaders, [Headers.getUserAgentHeader()])
  }

  func testConfigHeadersAreSet_whenInitCalledWithExplicitHeaders() throws {
    let exporter = try makeExporter(envVarHeaders: [("FOO", "BAR")])
    defer { exporter.shutdown() }
    XCTAssertNil(exporter.config.headers)

    XCTAssertEqual(exporter.export(logRecords: [makeLogRecord()]), .success)
    XCTAssertEqual(fakeCollector.receivedHeaders("FOO"), ["BAR"])
    XCTAssertEqual(fakeCollector.receivedUserAgentHeaders, [Headers.getUserAgentHeader()])
  }

  func testHeadersProviderIsEvaluatedForEveryExport() throws {
    let provider = MutableHeadersProvider([("authorization", "Bearer first")])
    let exporter = try makeExporter(
      config: OtlpConfiguration(headersProvider: provider.currentHeaders),
      envVarHeaders: nil
    )
    defer { exporter.shutdown() }
    let logRecord = makeLogRecord(severity: .info, body: "message")

    XCTAssertEqual(exporter.export(logRecords: [logRecord]), .success)
    provider.update([("authorization", "Bearer second")])
    XCTAssertEqual(exporter.export(logRecords: [logRecord]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer first", "Bearer second"])
    XCTAssertEqual(provider.callCount, 2)
  }

  func testExportAfterShutdown() throws {
    let logRecord = makeLogRecord()
    let exporter = try makeExporter()
    exporter.shutdown()
    let result = exporter.export(logRecords: [logRecord])
    XCTAssertEqual(result, ExportResult.failure)
  }

  func testExportCancelled() throws {
    fakeCollector.setError(RPCError(code: .cancelled, message: ""))
    let exporter = try makeExporter()
    let logRecord = makeLogRecord()
    let result = exporter.export(logRecords: [logRecord])
    XCTAssertEqual(result, ExportResult.failure)
    exporter.shutdown()
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class FakeLogCollector: Opentelemetry_Proto_Collector_Logs_V1_LogsService.ServiceProtocol, Sendable {
  private struct State {
    var receivedLogs = [Opentelemetry_Proto_Logs_V1_ResourceLogs]()
    var receivedMetadata = [Metadata]()
    var returnedError: RPCError?
  }

  private let state = Mutex(State())

  func export(
    request: ServerRequest<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest>,
    context: ServerContext
  ) async throws -> ServerResponse<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse> {
    let error = state.withLock { state in
      state.receivedLogs.append(contentsOf: request.message.resourceLogs)
      state.receivedMetadata.append(request.metadata)
      return state.returnedError
    }
    if let error {
      throw error
    }
    return ServerResponse(message: Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse())
  }

  var receivedLogs: [Opentelemetry_Proto_Logs_V1_ResourceLogs] {
    state.withLock { $0.receivedLogs }
  }

  var receivedAuthorizationHeaders: [String?] {
    receivedFirstHeaders("authorization")
  }

  var receivedUserAgentHeaders: [String?] {
    receivedFirstHeaders(Constants.HTTP.userAgent)
  }

  func receivedHeaders(_ name: String) -> [String] {
    state.withLock { $0.receivedMetadata.flatMap { Array($0[stringValues: name.lowercased()]) } }
  }

  func setError(_ error: RPCError?) {
    state.withLock { $0.returnedError = error }
  }

  private func receivedFirstHeaders(_ name: String) -> [String?] {
    state.withLock { $0.receivedMetadata.map { Array($0[stringValues: name]).first } }
  }
}

#endif

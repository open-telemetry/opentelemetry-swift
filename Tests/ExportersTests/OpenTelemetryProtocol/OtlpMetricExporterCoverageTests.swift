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
final class OtlpMetricExporterCoverageTests: XCTestCase {
  private var fakeCollector: FakeMetricCollector!
  private var server: OtlpGrpcTestServer<FakeMetricCollector>!

  override func setUp() async throws {
    fakeCollector = FakeMetricCollector()
    server = try await OtlpGrpcTestServer(service: fakeCollector)
  }

  override func tearDown() async throws {
    await server.stop()
  }

  private func sampleMetric() -> MetricData {
    let point = LongPointData(startEpochNanos: 0, endEpochNanos: 1,
                              attributes: [:], exemplars: [], value: 1)
    return MetricData.createLongSum(
      resource: Resource(attributes: ["s": .string("v")]),
      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
      name: "sum",
      description: "",
      unit: "",
      isMonotonic: true,
      data: SumData(aggregationTemporality: .cumulative, points: [point]))
  }

  private func makeExporter(
    config: OtlpConfiguration = OtlpConfiguration(),
    envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes
  ) throws -> OtlpMetricExporter {
    try OtlpMetricExporter(
      transport: server.makeClientTransport(),
      config: config,
      envVarHeaders: envVarHeaders
    )
  }

  func testExportSuccess() throws {
    let exporter = try makeExporter()
    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .success)
    XCTAssertFalse(fakeCollector.receivedMetrics.isEmpty)
    _ = exporter.shutdown()
  }

  func testExportFailurePropagatesStatus() throws {
    fakeCollector.setError(RPCError(code: .cancelled, message: ""))
    let exporter = try makeExporter()
    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .failure)
    _ = exporter.shutdown()
  }

  func testExportAppliesTimeout() throws {
    fakeCollector.setResponseDelay(.milliseconds(100))
    let exporter = try makeExporter(config: OtlpConfiguration(timeout: 0.01))

    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .failure)
    _ = exporter.shutdown()
  }

  func testConfigHeadersSetOnCallOptions() throws {
    let exporter = try makeExporter(
      config: OtlpConfiguration(headers: [("x-k", "x-v")]),
      envVarHeaders: nil
    )
    defer { _ = exporter.shutdown() }

    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .success)

    XCTAssertEqual(fakeCollector.receivedHeaders("x-k"), ["x-v"])
  }

  func testEnvVarHeadersSetOnCallOptions() throws {
    let exporter = try makeExporter(envVarHeaders: [("x-env", "v")])
    defer { _ = exporter.shutdown() }

    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .success)

    XCTAssertEqual(fakeCollector.receivedHeaders("x-env"), ["v"])
  }

  func testHeadersProviderIsEvaluatedForEveryExport() throws {
    let provider = MutableHeadersProvider([("authorization", "Bearer first")])
    let exporter = try makeExporter(
      config: OtlpConfiguration(headersProvider: provider.currentHeaders),
      envVarHeaders: nil
    )
    defer { _ = exporter.shutdown() }

    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .success)
    provider.update([("authorization", "Bearer second")])
    XCTAssertEqual(exporter.export(metrics: [sampleMetric()]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer first", "Bearer second"])
    XCTAssertEqual(provider.callCount, 2)
  }

  func testGetAggregationTemporalityReturnsConfigured() throws {
    let exporter = try makeExporter()
    XCTAssertEqual(exporter.getAggregationTemporality(for: .counter), .cumulative)
    _ = exporter.shutdown()
  }

  func testFlushReturnsSuccess() throws {
    let exporter = try makeExporter()
    XCTAssertEqual(exporter.flush(), .success)
    _ = exporter.shutdown()
  }

  func testShutdownReturnsSuccess() throws {
    let exporter = try makeExporter()
    XCTAssertEqual(exporter.shutdown(), .success)
  }

  func testSharedClientSurvivesOtherExporterShutdown() async throws {
    let traceCollector = FakeTraceCollector()
    let sharedServer = try await OtlpGrpcTestServer(
      service: TraceAndMetricsService(trace: traceCollector, metrics: fakeCollector)
    )
    let client = try GRPCClient(transport: sharedServer.makeClientTransport())
    let runTask = Task { try await client.runConnections() }
    let traceExporter = OtlpTraceExporter(client: client, envVarHeaders: nil)
    let metricExporter = OtlpMetricExporter(client: client, envVarHeaders: nil)

    await traceExporter.shutdown(explicitTimeout: nil)
    let traceResult = await traceExporter.export(spans: [makeSpan()], explicitTimeout: nil)
    let result = await metricExporter.export(metrics: [sampleMetric()])

    XCTAssertEqual(traceResult, .failure)
    XCTAssertEqual(result, .success)
    XCTAssertFalse(fakeCollector.receivedMetrics.isEmpty)
    XCTAssertEqual(traceCollector.requestCount, 0)

    client.beginGracefulShutdown()
    let runResult = await runTask.result
    await sharedServer.stop()
    try runResult.get()
  }

  private func makeSpan() -> SpanData {
    let start = Date()
    var span = SpanData(traceId: TraceId(fromHexString: "00000000000000000000000000abc123"),
                        spanId: SpanId(fromHexString: "0000000000def456"),
                        name: "GET /api/endpoint",
                        kind: SpanKind.server,
                        startTime: start,
                        endTime: start.addingTimeInterval(0.9))
    span.settingHasEnded(true)
    span.settingTotalRecordedEvents(0)
    span.settingLinks([SpanData.Link]())
    span.settingTotalRecordedLinks(0)
    span.settingStatus(.ok)
    return span
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private struct TraceAndMetricsService: RegistrableRPCService {
  let trace: FakeTraceCollector
  let metrics: FakeMetricCollector

  func registerMethods<Transport: ServerTransport>(with router: inout RPCRouter<Transport>) {
    trace.registerMethods(with: &router)
    metrics.registerMethods(with: &router)
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private final class FakeMetricCollector: Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.ServiceProtocol, Sendable {
  private struct State {
    var receivedMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()
    var receivedMetadata = [Metadata]()
    var returnedError: RPCError?
    var responseDelay: Duration?
  }

  private let state = Mutex(State())

  func export(
    request: ServerRequest<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest>,
    context: ServerContext
  ) async throws -> ServerResponse<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse> {
    let outcome = state.withLock { state in
      state.receivedMetrics.append(contentsOf: request.message.resourceMetrics)
      state.receivedMetadata.append(request.metadata)
      return (state.returnedError, state.responseDelay)
    }
    if let error = outcome.0 {
      throw error
    }
    if let delay = outcome.1 {
      try await Task.sleep(for: delay)
    }
    return ServerResponse(message: Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse())
  }

  var receivedMetrics: [Opentelemetry_Proto_Metrics_V1_ResourceMetrics] {
    state.withLock { $0.receivedMetrics }
  }

  var receivedAuthorizationHeaders: [String?] {
    state.withLock { $0.receivedMetadata.map { Array($0[stringValues: "authorization"]).first } }
  }

  func receivedHeaders(_ name: String) -> [String] {
    state.withLock { $0.receivedMetadata.flatMap { Array($0[stringValues: name]) } }
  }

  func setError(_ error: RPCError?) {
    state.withLock { $0.returnedError = error }
  }

  func setResponseDelay(_ delay: Duration?) {
    state.withLock { $0.responseDelay = delay }
  }
}

#endif

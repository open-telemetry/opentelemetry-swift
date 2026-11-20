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
final class OtlpTraceExporterTests: XCTestCase {
  let traceId = "00000000000000000000000000abc123"
  let spanId = "0000000000def456"

  var fakeCollector: FakeTraceCollector!
  var server: OtlpGrpcTestServer<FakeTraceCollector>!

  override func setUp() async throws {
    fakeCollector = FakeTraceCollector()
    server = try await OtlpGrpcTestServer(service: fakeCollector)
  }

  override func tearDown() async throws {
    await server.stop()
  }

  func testExport() throws {
    let span = generateFakeSpan()
    let exporter = try makeExporter()
    let result = exporter.export(spans: [span])
    XCTAssertEqual(result, SpanExporterResultCode.success)
    XCTAssertEqual(fakeCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: [span]))
    exporter.shutdown()
  }

  func verifyUserAgentIsSet(exporter: OtlpTraceExporter) {
    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)
    XCTAssertEqual(fakeCollector.receivedUserAgentHeaders, [Headers.getUserAgentHeader()])
  }

  func testConfigHeadersIsNil_whenDefaultInitCalled() throws {
    let exporter = try makeExporter()
    defer { exporter.shutdown() }
    XCTAssertNil(exporter.config.headers)

    verifyUserAgentIsSet(exporter: exporter)
  }

  func testConfigHeadersAreSet_whenInitCalledWithCustomConfig() throws {
    let config = OtlpConfiguration(timeout: TimeInterval(10), headers: [("FOO", "BAR")])
    let exporter = try makeExporter(config: config, envVarHeaders: nil)
    defer { exporter.shutdown() }
    XCTAssertNotNil(exporter.config.headers)
    XCTAssertEqual(exporter.config.headers?[0].0, "FOO")
    XCTAssertEqual(exporter.config.headers?[0].1, "BAR")

    verifyUserAgentIsSet(exporter: exporter)
    XCTAssertEqual(fakeCollector.receivedHeaders("FOO"), ["BAR"])
  }

  func testConfigHeadersAreSet_whenInitCalledWithExplicitHeaders() throws {
    let exporter = try makeExporter(envVarHeaders: [("FOO", "BAR")])
    defer { exporter.shutdown() }
    XCTAssertNil(exporter.config.headers)

    verifyUserAgentIsSet(exporter: exporter)
    XCTAssertEqual(fakeCollector.receivedHeaders("FOO"), ["BAR"])
  }

  func testStaticConfigHeadersReachCollector() throws {
    let exporter = try makeExporter(
      config: OtlpConfiguration(headers: [("authorization", "Bearer static")]),
      envVarHeaders: nil
    )
    defer { exporter.shutdown() }

    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer static"])
  }

  func testHeadersProviderIsEvaluatedForEveryExport() throws {
    let provider = MutableHeadersProvider([("authorization", "Bearer first")])
    let exporter = try makeExporter(
      config: OtlpConfiguration(
        headers: [
          ("x-static-header", "static-value"),
          ("Authorization", "Bearer static")
        ],
        headersProvider: provider.currentHeaders
      ),
      envVarHeaders: nil
    )
    defer { exporter.shutdown() }

    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)
    provider.update([("authorization", "Bearer second")])
    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer first", "Bearer second"])
    XCTAssertEqual(fakeCollector.receivedStaticHeaders, ["static-value", "static-value"])
    XCTAssertEqual(fakeCollector.receivedUserAgentHeaders, [
      Headers.getUserAgentHeader(),
      Headers.getUserAgentHeader()
    ])
    XCTAssertEqual(provider.callCount, 2)
  }

  func testEnvVarHeadersTakePrecedenceOverHeadersProvider() throws {
    let provider = MutableHeadersProvider([("authorization", "Bearer provider")])
    let exporter = try makeExporter(
      config: OtlpConfiguration(headersProvider: provider.currentHeaders),
      envVarHeaders: [("authorization", "Bearer environment")]
    )
    defer { exporter.shutdown() }

    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer environment"])
    XCTAssertEqual(provider.callCount, 0)
  }

  func testExportMultipleSpans() throws {
    var spans = [SpanData]()
    for _ in 0 ..< 10 {
      spans.append(generateFakeSpan())
    }
    let exporter = try makeExporter()
    let result = exporter.export(spans: spans)
    XCTAssertEqual(result, SpanExporterResultCode.success)
    XCTAssertEqual(fakeCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: spans))
    exporter.shutdown()
  }

  func testExportAfterShutdown() throws {
    let span = generateFakeSpan()
    let exporter = try makeExporter()
    exporter.shutdown()
    let result = exporter.export(spans: [span])
    XCTAssertEqual(result, SpanExporterResultCode.failure)
  }

  func testExportCancelled() throws {
    fakeCollector.setError(RPCError(code: .cancelled, message: ""))
    let exporter = try makeExporter()
    let span = generateFakeSpan()
    let result = exporter.export(spans: [span])
    XCTAssertEqual(result, SpanExporterResultCode.failure)
    exporter.shutdown()
  }

  func testExportFailureIsReported() throws {
    fakeCollector.setError(RPCError(code: .unavailable, message: "collector unavailable"))
    let exporter = try makeExporter()
    defer { exporter.shutdown() }
    withFeedbackRecorder { recorder in
      let result = exporter.export(spans: [generateFakeSpan()])

      XCTAssertEqual(result, .failure)
      XCTAssertEqual(recorder.messages.count, 1)
      guard let message = recorder.messages.first else {
        return XCTFail("Expected export failure feedback")
      }
      XCTAssertTrue(message.contains("OTLP trace export failed"))
      XCTAssertTrue(message.contains("collector unavailable"))
    }
  }

  func testRejectedSpansAreReported() throws {
    fakeCollector.setResponse(.with {
      $0.partialSuccess = .with {
        $0.rejectedSpans = 2
        $0.errorMessage = "invalid span data"
      }
    })
    let exporter = try makeExporter()
    defer { exporter.shutdown() }
    withFeedbackRecorder { recorder in
      let result = exporter.export(spans: [generateFakeSpan()])

      XCTAssertEqual(result, .success)
      XCTAssertEqual(recorder.messages, [
        "OTLP trace export partially succeeded: rejected_spans=2, error_message=invalid span data"
      ])
    }
  }

  func testPartialSuccessWarningIsReported() throws {
    fakeCollector.setResponse(.with {
      $0.partialSuccess = .with {
        $0.errorMessage = "consider reducing the batch size"
      }
    })
    let exporter = try makeExporter()
    defer { exporter.shutdown() }
    withFeedbackRecorder { recorder in
      let result = exporter.export(spans: [generateFakeSpan()])

      XCTAssertEqual(result, .success)
      XCTAssertEqual(recorder.messages, [
        "OTLP trace export succeeded with a warning: rejected_spans=0, error_message=consider reducing the batch size"
      ])
    }
  }

  func testEmptyPartialSuccessIsNotReported() throws {
    fakeCollector.setResponse(.with {
      $0.partialSuccess = Opentelemetry_Proto_Collector_Trace_V1_ExportTracePartialSuccess()
    })
    let exporter = try makeExporter()
    defer { exporter.shutdown() }
    withFeedbackRecorder { recorder in
      let result = exporter.export(spans: [generateFakeSpan()])

      XCTAssertEqual(result, .success)
      XCTAssertTrue(recorder.messages.isEmpty)
    }
  }

  func testExportWithUnstartedClientFailsWithinTimeout() throws {
    let client = try GRPCClient(transport: server.makeClientTransport())
    let exporter = OtlpTraceExporter(
      client: client,
      config: OtlpConfiguration(timeout: 0.5),
      envVarHeaders: nil
    )
    defer { client.beginGracefulShutdown() }

    let start = Date()
    let result = exporter.export(spans: [generateFakeSpan()])
    let elapsed = Date().timeIntervalSince(start)

    XCTAssertEqual(result, .failure)
    XCTAssertLessThan(elapsed, 3)
    XCTAssertEqual(fakeCollector.requestCount, 0)
  }

  func testConcurrentSyncExportsAllComplete() throws {
    let exporter = try makeExporter()
    defer { exporter.shutdown() }
    let span = generateFakeSpan()
    let results = ExportResults()

    DispatchQueue.concurrentPerform(iterations: 8) { _ in
      results.append(exporter.export(spans: [span]))
    }

    XCTAssertEqual(results.all, Array(repeating: SpanExporterResultCode.success, count: 8))
    XCTAssertEqual(fakeCollector.requestCount, 8)
  }

  func testGzipExportSucceedsOverLoopback() async throws {
    let gzipCollector = FakeTraceCollector()
    let gzipServer = try await OtlpGrpcTestServer(service: gzipCollector, compression: .all)
    let exporter = try OtlpTraceExporter(
      transport: gzipServer.makeClientTransport(compression: .all),
      config: OtlpConfiguration(compression: .gzip),
      envVarHeaders: nil
    )

    let span = generateFakeSpan()
    let result = await exporter.export(spans: [span], explicitTimeout: nil)

    XCTAssertEqual(result, .success)
    XCTAssertEqual(gzipCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: [span]))
    XCTAssertEqual(gzipCollector.receivedHeaders("grpc-encoding"), ["gzip"])
    await exporter.shutdown(explicitTimeout: 1)
    await gzipServer.stop()
  }

  func testAsyncExportSucceeds() async throws {
    let exporter = try makeExporter()
    let span = generateFakeSpan()

    let result = await exporter.export(spans: [span], explicitTimeout: nil)

    XCTAssertEqual(result, .success)
    XCTAssertEqual(fakeCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: [span]))
    await exporter.shutdown(explicitTimeout: 1)
  }

  private func makeExporter(
    config: OtlpConfiguration = OtlpConfiguration(),
    envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes
  ) throws -> OtlpTraceExporter {
    try OtlpTraceExporter(
      transport: server.makeClientTransport(),
      config: config,
      envVarHeaders: envVarHeaders
    )
  }

  private func withFeedbackRecorder(_ operation: (FeedbackRecorder) -> Void) {
    let previousHandler = OpenTelemetry.instance.feedbackHandler
    let recorder = FeedbackRecorder()
    OpenTelemetry.registerFeedbackHandler(recorder.record)
    defer {
      OpenTelemetry.registerFeedbackHandler(previousHandler ?? { _ in })
    }
    operation(recorder)
  }

  private func generateFakeSpan() -> SpanData {
    let duration = 0.9
    let start = Date()
    let end = start.addingTimeInterval(duration)

    var testData = SpanData(traceId: TraceId(fromHexString: traceId),
                            spanId: SpanId(fromHexString: spanId),
                            name: "GET /api/endpoint",
                            kind: SpanKind.server,
                            startTime: start,
                            endTime: end)
    testData.settingHasEnded(true)
    testData.settingTotalRecordedEvents(0)
    testData.settingLinks([SpanData.Link]())
    testData.settingTotalRecordedLinks(0)
    testData.settingStatus(.ok)

    return testData
  }
}

private final class FeedbackRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var recordedMessages = [String]()

  var messages: [String] {
    lock.lock()
    defer { lock.unlock() }
    return recordedMessages
  }

  func record(_ message: String) {
    lock.lock()
    defer { lock.unlock() }
    recordedMessages.append(message)
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private final class ExportResults: Sendable {
  private let results = Mutex<[SpanExporterResultCode]>([])

  var all: [SpanExporterResultCode] {
    results.withLock { $0 }
  }

  func append(_ result: SpanExporterResultCode) {
    results.withLock { $0.append(result) }
  }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class FakeTraceCollector: Opentelemetry_Proto_Collector_Trace_V1_TraceService.ServiceProtocol, Sendable {
  private struct State {
    var receivedSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans]()
    var receivedMetadata = [Metadata]()
    var returnedError: RPCError?
    var returnedResponse = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse()
  }

  private let state = Mutex(State())

  func export(
    request: ServerRequest<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest>,
    context: ServerContext
  ) async throws -> ServerResponse<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
    let outcome = state.withLock { state in
      state.receivedSpans.append(contentsOf: request.message.resourceSpans)
      state.receivedMetadata.append(request.metadata)
      return (state.returnedError, state.returnedResponse)
    }
    if let error = outcome.0 {
      throw error
    }
    return ServerResponse(message: outcome.1)
  }

  var receivedSpans: [Opentelemetry_Proto_Trace_V1_ResourceSpans] {
    state.withLock { $0.receivedSpans }
  }

  var requestCount: Int {
    state.withLock { $0.receivedMetadata.count }
  }

  var receivedAuthorizationHeaders: [String?] {
    receivedFirstHeaders("authorization")
  }

  var receivedStaticHeaders: [String?] {
    receivedFirstHeaders("x-static-header")
  }

  var receivedUserAgentHeaders: [String?] {
    receivedFirstHeaders(Constants.HTTP.userAgent)
  }

  func receivedHeaders(_ name: String) -> [String] {
    state.withLock { $0.receivedMetadata.flatMap { Array($0[stringValues: name]) } }
  }

  func setError(_ error: RPCError?) {
    state.withLock { $0.returnedError = error }
  }

  func setResponse(_ response: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse) {
    state.withLock { $0.returnedResponse = response }
  }

  private func receivedFirstHeaders(_ name: String) -> [String?] {
    state.withLock { $0.receivedMetadata.map { Array($0[stringValues: name]).first } }
  }
}

#endif

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import GRPC
import Logging
import NIO
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetrySdk
import XCTest

extension String: @retroactive Error {}
extension Swift.String: @retroactive LocalizedError {
  public var errorDescription: String? { return self }
}

class OtlpTraceExporterTests: XCTestCase {
  let traceId = "00000000000000000000000000abc123"
  let spanId = "0000000000def456"

  var fakeCollector: FakeCollector!
  var server: EventLoopFuture<Server>!
  var channel: ClientConnection!

  let channelGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

  override func setUp() {
    fakeCollector = FakeCollector()
    server = startServer()
    channel = startChannel()
  }

  override func tearDown() {
    try! serverGroup.syncShutdownGracefully()
    try! channelGroup.syncShutdownGracefully()
  }

  func testExport() {
    let span = generateFakeSpan()
    let exporter = OtlpTraceExporter(channel: channel)
    let result = exporter.export(spans: [span])
    XCTAssertEqual(result, SpanExporterResultCode.success)
    XCTAssertEqual(fakeCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: [span]))
    exporter.shutdown()
  }

  func testImplicitGrpcLoggingConfig() throws {
    let exporter = OtlpTraceExporter(channel: channel)
    let logger = exporter.callOptions.logger
    XCTAssertEqual(logger.label, "io.grpc")
  }

  func testExplicitGrpcLoggingConfig() throws {
    let exporter = OtlpTraceExporter(channel: channel, logger: Logger(label: "my.grpc.logger"))
    let logger = exporter.callOptions.logger
    XCTAssertEqual(logger.label, "my.grpc.logger")
  }

  func verifyUserAgentIsSet(exporter: OtlpTraceExporter) {
    let callOptions = exporter.callOptions
    let customMetadata = callOptions.customMetadata
    let userAgent = Headers.getUserAgentHeader()
    if customMetadata.contains(name: Constants.HTTP.userAgent), customMetadata.first(name: Constants.HTTP.userAgent) == userAgent {
      return
    }

    XCTFail("User-Agent header was not set correctly")
  }

  func testConfigHeadersIsNil_whenDefaultInitCalled() throws {
    let exporter = OtlpTraceExporter(channel: channel)
    XCTAssertNil(exporter.config.headers)

    verifyUserAgentIsSet(exporter: exporter)
  }

  func testConfigHeadersAreSet_whenInitCalledWithCustomConfig() throws {
    let config = OtlpConfiguration(timeout: TimeInterval(10), headers: [("FOO", "BAR")])
    let exporter = OtlpTraceExporter(channel: channel, config: config)
    XCTAssertNotNil(exporter.config.headers)
    XCTAssertEqual(exporter.config.headers?[0].0, "FOO")
    XCTAssertEqual(exporter.config.headers?[0].1, "BAR")
    XCTAssertEqual("BAR", exporter.callOptions.customMetadata.first(name: "FOO"))

    verifyUserAgentIsSet(exporter: exporter)
  }

  func testConfigHeadersAreSet_whenInitCalledWithExplicitHeaders() throws {
    let exporter = OtlpTraceExporter(channel: channel, envVarHeaders: [("FOO", "BAR")])
    XCTAssertNil(exporter.config.headers)
    XCTAssertEqual("BAR", exporter.callOptions.customMetadata.first(name: "FOO"))

    verifyUserAgentIsSet(exporter: exporter)
  }

  func testStaticConfigHeadersReachCollector() {
    let exporter = OtlpTraceExporter(
      channel: channel,
      config: OtlpConfiguration(headers: [("authorization", "Bearer static")]),
      envVarHeaders: nil
    )
    defer { exporter.shutdown() }

    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer static"])
  }

  func testHeadersProviderIsEvaluatedForEveryExport() {
    let provider = MutableHeadersProvider([("authorization", "Bearer first")])
    let exporter = OtlpTraceExporter(
      channel: channel,
      config: OtlpConfiguration(headersProvider: provider.currentHeaders),
      envVarHeaders: nil
    )
    defer { exporter.shutdown() }

    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)
    provider.update([("authorization", "Bearer second")])
    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer first", "Bearer second"])
    XCTAssertEqual(fakeCollector.receivedUserAgentHeaders, [
      Headers.getUserAgentHeader(),
      Headers.getUserAgentHeader()
    ])
    XCTAssertEqual(provider.callCount, 2)
  }

  func testEnvVarHeadersTakePrecedenceOverHeadersProvider() {
    let provider = MutableHeadersProvider([("authorization", "Bearer provider")])
    let exporter = OtlpTraceExporter(
      channel: channel,
      config: OtlpConfiguration(headersProvider: provider.currentHeaders),
      envVarHeaders: [("authorization", "Bearer environment")]
    )
    defer { exporter.shutdown() }

    XCTAssertEqual(exporter.export(spans: [generateFakeSpan()]), .success)

    XCTAssertEqual(fakeCollector.receivedAuthorizationHeaders, ["Bearer environment"])
    XCTAssertEqual(provider.callCount, 0)
  }

  func testExportMultipleSpans() {
    var spans = [SpanData]()
    for _ in 0 ..< 10 {
      spans.append(generateFakeSpan())
    }
    let exporter = OtlpTraceExporter(channel: channel)
    let result = exporter.export(spans: spans)
    XCTAssertEqual(result, SpanExporterResultCode.success)
    XCTAssertEqual(fakeCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: spans))
    exporter.shutdown()
  }

  func testExportAfterShutdown() {
    let span = generateFakeSpan()
    let exporter = OtlpTraceExporter(channel: channel)
    exporter.shutdown()
    let result = exporter.export(spans: [span])
    XCTAssertEqual(result, SpanExporterResultCode.failure)
  }

  func testExportCancelled() {
    fakeCollector.returnedStatus = GRPCStatus(code: .cancelled, message: nil)
    let exporter = OtlpTraceExporter(channel: channel)
    let span = generateFakeSpan()
    let result = exporter.export(spans: [span])
    XCTAssertEqual(result, SpanExporterResultCode.failure)
    exporter.shutdown()
  }

  func testExportFailureIsReported() {
    let expectedStatus = GRPCStatus(code: .unavailable, message: "collector unavailable")
    fakeCollector.returnedStatus = expectedStatus
    withFeedbackRecorder { recorder in
      let exporter = OtlpTraceExporter(channel: channel)
      defer { exporter.shutdown() }

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

  func testRejectedSpansAreReported() {
    fakeCollector.returnedResponse = .with {
      $0.partialSuccess = .with {
        $0.rejectedSpans = 2
        $0.errorMessage = "invalid span data"
      }
    }
    withFeedbackRecorder { recorder in
      let exporter = OtlpTraceExporter(channel: channel)
      defer { exporter.shutdown() }

      let result = exporter.export(spans: [generateFakeSpan()])

      XCTAssertEqual(result, .success)
      XCTAssertEqual(recorder.messages, [
        "OTLP trace export partially succeeded: rejected_spans=2, error_message=invalid span data"
      ])
    }
  }

  func testPartialSuccessWarningIsReported() {
    fakeCollector.returnedResponse = .with {
      $0.partialSuccess = .with {
        $0.errorMessage = "consider reducing the batch size"
      }
    }
    withFeedbackRecorder { recorder in
      let exporter = OtlpTraceExporter(channel: channel)
      defer { exporter.shutdown() }

      let result = exporter.export(spans: [generateFakeSpan()])

      XCTAssertEqual(result, .success)
      XCTAssertEqual(recorder.messages, [
        "OTLP trace export succeeded with a warning: rejected_spans=0, error_message=consider reducing the batch size"
      ])
    }
  }

  func testEmptyPartialSuccessIsNotReported() {
    fakeCollector.returnedResponse = .with {
      $0.partialSuccess = Opentelemetry_Proto_Collector_Trace_V1_ExportTracePartialSuccess()
    }
    withFeedbackRecorder { recorder in
      let exporter = OtlpTraceExporter(channel: channel)
      defer { exporter.shutdown() }

      let result = exporter.export(spans: [generateFakeSpan()])

      XCTAssertEqual(result, .success)
      XCTAssertTrue(recorder.messages.isEmpty)
    }
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

  func startServer() -> EventLoopFuture<Server> {
    // Start the server and print its address once it has started.
    let server = Server.insecure(group: serverGroup)
      .withServiceProviders([fakeCollector])
      .bind(host: "localhost", port: 4317)

    server.map(\.channel.localAddress).whenSuccess { address in
      print("server started on port \(address!.port!)")
    }
    return server
  }

  func startChannel() -> ClientConnection {
    let channel = ClientConnection.insecure(group: channelGroup)
      .connect(host: "localhost", port: 4317)
    return channel
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

class FakeCollector: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceProvider {
  var receivedSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans]()
  var receivedAuthorizationHeaders = [String?]()
  var receivedUserAgentHeaders = [String?]()
  var returnedStatus = GRPCStatus.ok
  var returnedResponse = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse()
  var interceptors: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceServerInterceptorFactoryProtocol?

  func export(request: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
    receivedSpans.append(contentsOf: request.resourceSpans)
    receivedAuthorizationHeaders.append(context.headers.first(name: "authorization"))
    receivedUserAgentHeaders.append(context.headers.first(name: Constants.HTTP.userAgent))
    if returnedStatus != GRPCStatus.ok {
      return context.eventLoop.makeFailedFuture(returnedStatus)
    }
    return context.eventLoop.makeSucceededFuture(returnedResponse)
  }
}

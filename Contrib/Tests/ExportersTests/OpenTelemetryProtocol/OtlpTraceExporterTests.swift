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

class FakeCollector: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceProvider {
  var receivedSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans]()
  var returnedStatus = GRPCStatus.ok
  var interceptors: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceServerInterceptorFactoryProtocol?

  func export(request: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
    receivedSpans.append(contentsOf: request.resourceSpans)
    if returnedStatus != GRPCStatus.ok {
      return context.eventLoop.makeFailedFuture(returnedStatus)
    }
    return context.eventLoop.makeSucceededFuture(Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse())
  }
}

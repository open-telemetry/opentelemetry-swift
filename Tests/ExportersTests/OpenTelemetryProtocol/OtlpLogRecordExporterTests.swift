//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging
import GRPC
import NIO
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetrySdk
import XCTest


class OtlpLogRecordExporterTests: XCTestCase {
  let traceIdBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4]
  let spanIdBytes: [UInt8] = [0, 0, 0, 0, 4, 3, 2, 1]
  var traceId: TraceId!
  var spanId: SpanId!
  let tracestate = TraceState()
  var spanContext: SpanContext!
  
  
  
  
  var fakeCollector: FakeLogCollector!
  var server: EventLoopFuture<Server>!
  var channel: ClientConnection!
  
  let channelGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  let serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  
  func startServer() -> EventLoopFuture<Server> {
    // Start the server and print its address once it has started.
    let server = Server.insecure(group: serverGroup)
      .withServiceProviders([fakeCollector])
      .bind(host: "localhost", port: 4317)
    
    server.map {
      $0.channel.localAddress
    }.whenSuccess { address in
      print("server started on port \(address!.port!)")
    }
    return server
  }
  
  func startChannel() -> ClientConnection {
    let channel = ClientConnection.insecure(group: channelGroup)
      .connect(host: "localhost", port: 4317)
    return channel
  }
  
  override func setUp() {
    fakeCollector = FakeLogCollector()
    server = startServer()
    channel = startChannel()
    traceId = TraceId(fromBytes: traceIdBytes)
    spanId = SpanId(fromBytes: spanIdBytes)
    spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: tracestate)
    
  }
  
  override func tearDown() {
    try! serverGroup.syncShutdownGracefully()
    try! channelGroup.syncShutdownGracefully()
  }
  
  func testExport() {
    let logRecord = ReadableLogRecord(resource: Resource(),
                                      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                                      timestamp: Date(),
                                      observedTimestamp: Date.distantPast,
                                      spanContext: spanContext,
                                      severity: .fatal,
                                      body: AttributeValue.string("Hello, world"),
                                      attributes: ["event.name":AttributeValue.string("name"), "event.domain": AttributeValue.string("domain")])
    
    let exporter = OtlpLogExporter(channel: channel)
    let result = exporter.export(logRecords: [logRecord])
    XCTAssertEqual(result, ExportResult.success)
    XCTAssertEqual(fakeCollector.receivedLogs, LogRecordAdapter.toProtoResourceRecordLog(logRecordList: [logRecord]))
    exporter.shutdown()
  }
  
  func testImplicitGrpcLoggingConfig() throws {
    let exporter = OtlpLogExporter(channel: channel)
    let logger = exporter.callOptions.logger
    XCTAssertEqual(logger.label, "io.grpc")
  }
  func testExplicitGrpcLoggingConfig() throws {
    let exporter = OtlpLogExporter(channel: channel, logger: Logger(label: "my.grpc.logger"))
    let logger = exporter.callOptions.logger  
    XCTAssertEqual(logger.label, "my.grpc.logger")
  }
  
  func testConfigHeadersIsNil_whenDefaultInitCalled() throws {
    let exporter = OtlpLogExporter(channel: channel)
    XCTAssertNil(exporter.config.headers)
  }
  
  func testConfigHeadersAreSet_whenInitCalledWithCustomConfig() throws {
    let config: OtlpConfiguration = OtlpConfiguration(timeout: TimeInterval(10), headers: [("FOO", "BAR")])
    let exporter = OtlpLogExporter(channel: channel, config: config)
    XCTAssertNotNil(exporter.config.headers)
    XCTAssertEqual(exporter.config.headers?[0].0, "FOO")
    XCTAssertEqual(exporter.config.headers?[0].1, "BAR")
    XCTAssertEqual("BAR", exporter.callOptions.customMetadata.first(name: "FOO"))
  }
  
  func testConfigHeadersAreSet_whenInitCalledWithExplicitHeaders() throws {
    let exporter = OtlpLogExporter(channel: channel, envVarHeaders: [("FOO", "BAR")])
    XCTAssertNil(exporter.config.headers)
    XCTAssertEqual("BAR", exporter.callOptions.customMetadata.first(name: "FOO"))
  }
  
  func testExportAfterShutdown() {
    let logRecord = ReadableLogRecord(resource: Resource(),
                                      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                                      timestamp: Date(),
                                      observedTimestamp: Date.distantPast,
                                      spanContext: spanContext,
                                      severity: .fatal,
                                      body: AttributeValue.string("Hello, world"),
                                      attributes: ["event.name":AttributeValue.string("name"), "event.domain": AttributeValue.string("domain")])
    let exporter = OtlpLogExporter(channel: channel)
    exporter.shutdown()
    let result = exporter.export(logRecords: [logRecord])
    XCTAssertEqual(result, ExportResult.failure)
  }
  
  func testExportCancelled() {
    fakeCollector.returnedStatus = GRPCStatus(code: .cancelled, message: nil)
    let exporter = OtlpLogExporter(channel: channel)
    let logRecord = ReadableLogRecord(resource: Resource(),
                                      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                                      timestamp: Date(),
                                      observedTimestamp: Date.distantPast,
                                      spanContext: spanContext,
                                      severity: .fatal,
                                      body: AttributeValue.string("Hello, world"),
                                      attributes: ["event.name":AttributeValue.string("name"),
                                                   "event.domain": AttributeValue.string("domain")])
    let result = exporter.export(logRecords: [logRecord])
    XCTAssertEqual(result, ExportResult.failure)
    exporter.shutdown()
  }
  
}



class FakeLogCollector: Opentelemetry_Proto_Collector_Logs_V1_LogsServiceProvider  {
  var interceptors: Opentelemetry_Proto_Collector_Logs_V1_LogsServiceServerInterceptorFactoryProtocol?
  
  func export(request: Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest, context: GRPC.StatusOnlyCallContext) -> NIOCore.EventLoopFuture<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse> {
    receivedLogs.append(contentsOf: request.resourceLogs)
    if returnedStatus != GRPCStatus.ok {
      return context.eventLoop.makeFailedFuture(returnedStatus)
    }
    return context.eventLoop.makeSucceededFuture(Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse())
  }
  
  var receivedLogs = [Opentelemetry_Proto_Logs_V1_ResourceLogs]()
  var returnedStatus = GRPCStatus.ok
  
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetrySdk
import Synchronization
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class OtlpGrpcConnectionTests: XCTestCase {
  var fakeCollector: FakeTraceCollector!
  var server: OtlpGrpcTestServer<FakeTraceCollector>!

  override func setUp() async throws {
    fakeCollector = FakeTraceCollector()
    server = try await OtlpGrpcTestServer(service: fakeCollector)
  }

  override func tearDown() async throws {
    await server.stop()
  }

  func testOwnedClientStopsOnShutdown() async throws {
    let exporter = try OtlpTraceExporter(transport: server.makeClientTransport(), envVarHeaders: nil)
    let exportedBeforeShutdown = await exporter.export(spans: [makeSpan()], explicitTimeout: nil)
    XCTAssertEqual(exportedBeforeShutdown, .success)

    await exporter.shutdown()
    XCTAssertTrue(exporter.connection.isShutdown)
    let exportedAfterShutdown = await exporter.export(spans: [makeSpan()], explicitTimeout: nil)
    XCTAssertEqual(exportedAfterShutdown, .failure)

    let start = Date()
    await exporter.connection.shutdown(timeout: 1)
    let elapsed = Date().timeIntervalSince(start)
    XCTAssertLessThan(elapsed, 2)
    XCTAssertLessThan(elapsed, 1, "The client stopped on its own instead of at the timeout")
  }

  func testCallerOwnedClientKeepsRunningAfterShutdown() async throws {
    let client = try GRPCClient(transport: server.makeClientTransport())
    let runFinished = Mutex(false)
    let runTask = Task {
      try? await client.runConnections()
      runFinished.withLock { $0 = true }
    }

    let first = OtlpTraceExporter(client: client, envVarHeaders: nil)
    let exportedByFirst = await first.export(spans: [makeSpan()], explicitTimeout: nil)
    XCTAssertEqual(exportedByFirst, .success)

    await first.shutdown(explicitTimeout: 1)
    XCTAssertTrue(first.connection.isShutdown)

    let second = OtlpTraceExporter(client: client, envVarHeaders: nil)
    let exportedBySecond = await second.export(spans: [makeSpan()], explicitTimeout: nil)
    XCTAssertEqual(exportedBySecond, .success)
    XCTAssertFalse(runFinished.withLock { $0 }, "Shutting down an exporter must not stop a client the caller owns")
    XCTAssertEqual(fakeCollector.requestCount, 2)

    client.beginGracefulShutdown()
    await runTask.value
    XCTAssertTrue(runFinished.withLock { $0 })
  }

  func testCallerOwnedExportAfterShutdownFails() async throws {
    let client = try GRPCClient(transport: server.makeClientTransport())
    let runTask = Task { try? await client.runConnections() }
    let exporter = OtlpTraceExporter(client: client, envVarHeaders: nil)
    let exportedBeforeShutdown = await exporter.export(spans: [makeSpan()], explicitTimeout: nil)
    XCTAssertEqual(exportedBeforeShutdown, .success)
    let receivedBeforeShutdown = fakeCollector.requestCount

    await exporter.shutdown()
    let exportedAfterShutdown = await exporter.export(spans: [makeSpan()], explicitTimeout: nil)

    XCTAssertEqual(exportedAfterShutdown, .failure)
    XCTAssertEqual(fakeCollector.requestCount, receivedBeforeShutdown)

    client.beginGracefulShutdown()
    await runTask.value
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

#endif

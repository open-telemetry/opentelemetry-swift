/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

// MARK: - Test Mocks

/// An exporter that provides native async implementations.
private class AsyncCapableSpanExporter: SpanExporter, @unchecked Sendable {
  var exportAsyncCalledTimes = 0
  var flushAsyncCalledTimes = 0
  var shutdownAsyncCalledTimes = 0
  var returnValue: SpanExporterResultCode = .success

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    fatalError("Sync export should not be called on an async-capable exporter")
  }

  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    fatalError("Sync flush should not be called on an async-capable exporter")
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    fatalError("Sync shutdown should not be called on an async-capable exporter")
  }

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) async -> SpanExporterResultCode {
    exportAsyncCalledTimes += 1
    return returnValue
  }

  func flush(explicitTimeout: TimeInterval?) async -> SpanExporterResultCode {
    flushAsyncCalledTimes += 1
    return returnValue
  }

  func shutdown(explicitTimeout: TimeInterval?) async {
    shutdownAsyncCalledTimes += 1
  }
}

/// A sync-only exporter used for MultiSpanExporter tests and sync compatibility.
private class SyncOnlySpanExporter: SpanExporter, @unchecked Sendable {
  var exportCalledTimes = 0
  var flushCalledTimes = 0
  var shutdownCalledTimes = 0
  var returnValue: SpanExporterResultCode = .success

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    exportCalledTimes += 1
    return returnValue
  }

  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    flushCalledTimes += 1
    return returnValue
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    shutdownCalledTimes += 1
  }
}

// MARK: - Tests

class AsyncSpanExporterTests: XCTestCase {
  private var spanList: [SpanData]!

  override func setUp() {
    spanList = [TestUtils.makeBasicSpan()]
  }

  // MARK: Async-capable exporter tests

  func testAsyncExporterExport() async {
    let exporter = AsyncCapableSpanExporter()
    exporter.returnValue = .success
    let result = await exporter.export(spans: spanList)
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.exportAsyncCalledTimes, 1)
  }

  func testAsyncExporterFlush() async {
    let exporter = AsyncCapableSpanExporter()
    exporter.returnValue = .success
    let result = await exporter.flush()
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.flushAsyncCalledTimes, 1)
  }

  func testAsyncExporterShutdown() async {
    let exporter = AsyncCapableSpanExporter()
    await exporter.shutdown()
    XCTAssertEqual(exporter.shutdownAsyncCalledTimes, 1)
  }

  func testAsyncExporterPropagatesFailure() async {
    let exporter = AsyncCapableSpanExporter()
    exporter.returnValue = .failure
    let result = await exporter.export(spans: spanList)
    XCTAssertEqual(result, .failure)
  }

  // MARK: MultiSpanExporter async tests

  func testMultiSpanExporterAsyncExportConcurrent() async {
    let exporter1 = SyncOnlySpanExporter()
    let exporter2 = SyncOnlySpanExporter()

    let multi = MultiSpanExporter(spanExporters: [exporter1, exporter2])
    let result = await multi.export(spans: spanList)
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter1.exportCalledTimes, 1)
    XCTAssertEqual(exporter2.exportCalledTimes, 1)
  }

  func testMultiSpanExporterAsyncExportMergesFailure() async {
    let exporter1 = SyncOnlySpanExporter()
    let exporter2 = SyncOnlySpanExporter()
    exporter1.returnValue = .success
    exporter2.returnValue = .failure

    let multi = MultiSpanExporter(spanExporters: [exporter1, exporter2])
    let result = await multi.export(spans: spanList)
    XCTAssertEqual(result, .failure)
  }

  func testMultiSpanExporterAsyncFlushConcurrent() async {
    let exporter1 = SyncOnlySpanExporter()
    let exporter2 = SyncOnlySpanExporter()

    let multi = MultiSpanExporter(spanExporters: [exporter1, exporter2])
    let result = await multi.flush()
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter1.flushCalledTimes, 1)
    XCTAssertEqual(exporter2.flushCalledTimes, 1)
  }

  func testMultiSpanExporterAsyncShutdownConcurrent() async {
    let exporter1 = SyncOnlySpanExporter()
    let exporter2 = SyncOnlySpanExporter()

    let multi = MultiSpanExporter(spanExporters: [exporter1, exporter2])
    await multi.shutdown()
    XCTAssertEqual(exporter1.shutdownCalledTimes, 1)
    XCTAssertEqual(exporter2.shutdownCalledTimes, 1)
  }

  // MARK: Sync compatibility

  func testSyncMethodsStillWork() {
    let exporter = SyncOnlySpanExporter()
    exporter.returnValue = .success
    let result = exporter.export(spans: spanList)
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.exportCalledTimes, 1)
  }
}

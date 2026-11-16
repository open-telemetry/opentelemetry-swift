/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

// MARK: - Test Mocks

/// An exporter that provides native async implementations.
private final class AsyncCapableLogExporter: LogRecordExporter {
  private let state = Locked(initialValue: State())

  struct State {
    var exportAsyncCalledTimes = 0
    var flushAsyncCalledTimes = 0
    var shutdownAsyncCalledTimes = 0
    var returnValue: ExportResult = .success
  }

  var exportAsyncCalledTimes: Int { state.locking { $0.exportAsyncCalledTimes } }
  var flushAsyncCalledTimes: Int { state.locking { $0.flushAsyncCalledTimes } }
  var shutdownAsyncCalledTimes: Int { state.locking { $0.shutdownAsyncCalledTimes } }

  var returnValue: ExportResult {
    get { state.locking { $0.returnValue } }
    set { state.locking { $0.returnValue = newValue } }
  }

  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    fatalError("Sync export should not be called on an async-capable exporter")
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    fatalError("Sync forceFlush should not be called on an async-capable exporter")
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    fatalError("Sync shutdown should not be called on an async-capable exporter")
  }

  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) async -> ExportResult {
    state.locking { state in
      state.exportAsyncCalledTimes += 1
      return state.returnValue
    }
  }

  func forceFlush(explicitTimeout: TimeInterval?) async -> ExportResult {
    state.locking { state in
      state.flushAsyncCalledTimes += 1
      return state.returnValue
    }
  }

  func shutdown(explicitTimeout: TimeInterval?) async {
    state.locking { $0.shutdownAsyncCalledTimes += 1 }
  }
}

/// A sync-only exporter used for MultiLogRecordExporter tests and sync compatibility.
private final class SyncOnlyLogExporter: LogRecordExporter {
  private let state = Locked(initialValue: State())

  struct State {
    var exportCalledTimes = 0
    var flushCalledTimes = 0
    var shutdownCalledTimes = 0
    var returnValue: ExportResult = .success
  }

  var exportCalledTimes: Int { state.locking { $0.exportCalledTimes } }
  var flushCalledTimes: Int { state.locking { $0.flushCalledTimes } }
  var shutdownCalledTimes: Int { state.locking { $0.shutdownCalledTimes } }

  var returnValue: ExportResult {
    get { state.locking { $0.returnValue } }
    set { state.locking { $0.returnValue = newValue } }
  }

  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    state.locking { state in
      state.exportCalledTimes += 1
      return state.returnValue
    }
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    state.locking { state in
      state.flushCalledTimes += 1
      return state.returnValue
    }
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    state.locking { $0.shutdownCalledTimes += 1 }
  }
}

// MARK: - Helper

private func makeLogRecord() -> ReadableLogRecord {
  return ReadableLogRecord(
    resource: Resource(),
    instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
    timestamp: Date(),
    attributes: [String: AttributeValue]()
  )
}

// MARK: - Tests

class AsyncLogRecordExporterTests: XCTestCase {
  // MARK: Async-capable exporter tests

  func testAsyncExporterExport() async {
    let exporter = AsyncCapableLogExporter()
    exporter.returnValue = .success
    let result = await exporter.export(logRecords: [makeLogRecord()])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.exportAsyncCalledTimes, 1)
  }

  func testAsyncExporterFlush() async {
    let exporter = AsyncCapableLogExporter()
    let result = await exporter.forceFlush()
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.flushAsyncCalledTimes, 1)
  }

  func testAsyncExporterShutdown() async {
    let exporter = AsyncCapableLogExporter()
    await exporter.shutdown()
    XCTAssertEqual(exporter.shutdownAsyncCalledTimes, 1)
  }

  func testAsyncExporterPropagatesFailure() async {
    let exporter = AsyncCapableLogExporter()
    exporter.returnValue = .failure
    let result = await exporter.export(logRecords: [makeLogRecord()])
    XCTAssertEqual(result, .failure)
  }

  // MARK: MultiLogRecordExporter async tests

  func testMultiLogExporterAsyncExport() async {
    let exporter1 = SyncOnlyLogExporter()
    let exporter2 = SyncOnlyLogExporter()

    let multi = MultiLogRecordExporter(logRecordExporters: [exporter1, exporter2])
    let result = await multi.export(logRecords: [makeLogRecord()])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter1.exportCalledTimes, 1)
    XCTAssertEqual(exporter2.exportCalledTimes, 1)
  }

  func testMultiLogExporterAsyncExportMergesFailure() async {
    let exporter1 = SyncOnlyLogExporter()
    let exporter2 = SyncOnlyLogExporter()
    exporter1.returnValue = .success
    exporter2.returnValue = .failure

    let multi = MultiLogRecordExporter(logRecordExporters: [exporter1, exporter2])
    let result = await multi.export(logRecords: [makeLogRecord()])
    XCTAssertEqual(result, .failure)
  }

  func testMultiLogExporterAsyncFlush() async {
    let exporter1 = SyncOnlyLogExporter()
    let exporter2 = SyncOnlyLogExporter()

    let multi = MultiLogRecordExporter(logRecordExporters: [exporter1, exporter2])
    let result = await multi.forceFlush()
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter1.flushCalledTimes, 1)
    XCTAssertEqual(exporter2.flushCalledTimes, 1)
  }

  func testMultiLogExporterAsyncShutdown() async {
    let exporter1 = SyncOnlyLogExporter()
    let exporter2 = SyncOnlyLogExporter()

    let multi = MultiLogRecordExporter(logRecordExporters: [exporter1, exporter2])
    await multi.shutdown()
    XCTAssertEqual(exporter1.shutdownCalledTimes, 1)
    XCTAssertEqual(exporter2.shutdownCalledTimes, 1)
  }

  // MARK: Sync compatibility

  func testSyncMethodsStillWork() {
    let exporter = SyncOnlyLogExporter()
    let result = exporter.export(logRecords: [makeLogRecord()])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.exportCalledTimes, 1)
  }
}

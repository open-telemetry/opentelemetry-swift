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
private final class AsyncCapableMetricExporter: MetricExporter, @unchecked Sendable {
  var exportAsyncCalledTimes = 0
  var flushAsyncCalledTimes = 0
  var shutdownAsyncCalledTimes = 0
  var returnValue: ExportResult = .success

  func export(metrics: [MetricData]) -> ExportResult {
    fatalError("Sync export should not be called on an async-capable exporter")
  }

  func flush() -> ExportResult {
    fatalError("Sync flush should not be called on an async-capable exporter")
  }

  func shutdown() -> ExportResult {
    fatalError("Sync shutdown should not be called on an async-capable exporter")
  }

  func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    return .cumulative
  }

  func export(metrics: [MetricData]) async -> ExportResult {
    exportAsyncCalledTimes += 1
    return returnValue
  }

  func flush() async -> ExportResult {
    flushAsyncCalledTimes += 1
    return returnValue
  }

  func shutdown() async -> ExportResult {
    shutdownAsyncCalledTimes += 1
    return returnValue
  }
}

/// A sync-only exporter for sync compatibility tests.
private final class SyncOnlyMetricExporter: MetricExporter, @unchecked Sendable {
  var exportCalledTimes = 0
  var flushCalledTimes = 0
  var shutdownCalledTimes = 0
  var returnValue: ExportResult = .success

  func export(metrics: [MetricData]) -> ExportResult {
    exportCalledTimes += 1
    return returnValue
  }

  func flush() -> ExportResult {
    flushCalledTimes += 1
    return returnValue
  }

  func shutdown() -> ExportResult {
    shutdownCalledTimes += 1
    return returnValue
  }

  func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    return .cumulative
  }
}

// MARK: - Tests

class AsyncMetricExporterTests: XCTestCase {
  // MARK: Async-capable exporter tests

  func testAsyncExporterExport() async {
    let exporter = AsyncCapableMetricExporter()
    exporter.returnValue = .success
    let result = await exporter.export(metrics: [MetricData.empty])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.exportAsyncCalledTimes, 1)
  }

  func testAsyncExporterFlush() async {
    let exporter = AsyncCapableMetricExporter()
    let result = await exporter.flush()
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.flushAsyncCalledTimes, 1)
  }

  func testAsyncExporterShutdown() async {
    let exporter = AsyncCapableMetricExporter()
    let result = await exporter.shutdown()
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.shutdownAsyncCalledTimes, 1)
  }

  func testAsyncExporterPropagatesFailure() async {
    let exporter = AsyncCapableMetricExporter()
    exporter.returnValue = .failure
    let result = await exporter.export(metrics: [MetricData.empty])
    XCTAssertEqual(result, .failure)
  }

  // MARK: Sync compatibility

  func testSyncMethodsStillWork() {
    let exporter = SyncOnlyMetricExporter()
    let result = exporter.export(metrics: [MetricData.empty])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(exporter.exportCalledTimes, 1)
  }
}

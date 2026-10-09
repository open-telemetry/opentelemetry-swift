//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class PeriodicMetricReaderSdkTests: XCTestCase {
  private let exportInterval: TimeInterval = 0.05
  private let flushQueue = DispatchQueue(label: "PeriodicMetricReaderSdkTests.flush", qos: .userInitiated)
  private let verifyQueue = DispatchQueue(label: "PeriodicMetricReaderSdkTests.verify", qos: .userInitiated)

  func testScheduledExportQueuesWhileExportIsBlocked() {
    let blockingExporter = CountingBlockingMetricExporter(aggregationTemporality: .delta)
    let meterProvider = makeMeterProvider(exporter: blockingExporter)
    let counter: LongCounterSdk = meterProvider
      .meterBuilder(name: "meter")
      .build()
      .counterBuilder(name: "counter")
      .build()

    counter.add(value: 1)
    blockingExporter.waitUntilIsBlocked()
    XCTAssertEqual(blockingExporter.exportCallCount, 1)

    let endTime = Date().addingTimeInterval(exportInterval * 3)
    while Date() < endTime {
      counter.add(value: 1)
      Thread.sleep(forTimeInterval: 0.01)
    }

    XCTAssertEqual(blockingExporter.exportCallCount, 1)

    blockingExporter.unblock()
    let secondExportCompleted = expectation(description: "second export completed")
    verifyQueue.async {
      while blockingExporter.exportCallCount < 2 {
        Thread.sleep(forTimeInterval: 0.01)
      }
      secondExportCompleted.fulfill()
    }
    wait(for: [secondExportCompleted], timeout: 1.0)

    _ = meterProvider.shutdown()
  }

  func testTimerKeepsEnqueueingWhileExportIsBlocked() {
    let blockingExporter = CountingBlockingMetricExporter(aggregationTemporality: .delta)
    let meterProvider = makeMeterProvider(exporter: blockingExporter)
    let counter: LongCounterSdk = meterProvider
      .meterBuilder(name: "meter")
      .build()
      .counterBuilder(name: "counter")
      .build()

    counter.add(value: 1)
    blockingExporter.waitUntilIsBlocked()
    XCTAssertEqual(blockingExporter.exportCallCount, 1)

    // Keep recording so queued collections have delta data after unblock.
    let endTime = Date().addingTimeInterval(exportInterval * 8)
    while Date() < endTime {
      counter.add(value: 1)
      Thread.sleep(forTimeInterval: 0.01)
    }

    // Timer should keep enqueueing exports without blocking on the slow upload.
    XCTAssertEqual(blockingExporter.exportCallCount, 1)

    blockingExporter.unblock()
    let start = Date()
    let deadline = Date().addingTimeInterval(1.0)
    while blockingExporter.exportCallCount <= 2, Date() < deadline {
      counter.add(value: 1)
      Thread.sleep(forTimeInterval: 0.01)
    }
    XCTAssertGreaterThan(blockingExporter.exportCallCount, 2)
    XCTAssertLessThan(Date().timeIntervalSince(start), 0.3)

    _ = meterProvider.shutdown()
  }

  func testForceFlushWaitsForInFlightExport() {
    let blockingExporter = CountingBlockingMetricExporter(aggregationTemporality: .delta)
    let reader = PeriodicMetricReaderSdk(exporter: blockingExporter, exportInterval: exportInterval)
    let meterProvider = makeMeterProvider(reader: reader)
    let counter = meterProvider.meterBuilder(name: "meter").build().counterBuilder(name: "counter").build()

    counter.add(value: 1)
    blockingExporter.waitUntilIsBlocked()

    let flushCompleted = expectation(description: "forceFlush completed")
    let flushFinished = Locked(initialValue: false)
    let flushSucceeded = Locked(initialValue: false)
    flushQueue.async {
      flushSucceeded.locking { $0 = reader.forceFlush() == .success }
      flushFinished.locking { $0 = true }
      flushCompleted.fulfill()
    }

    let stillBlocked = expectation(description: "flush still blocked")
    verifyQueue.async {
      Thread.sleep(forTimeInterval: 0.1)
      stillBlocked.fulfill()
    }
    wait(for: [stillBlocked], timeout: 0.2)
    XCTAssertFalse(flushFinished.locking { $0 })

    blockingExporter.unblock()
    wait(for: [flushCompleted], timeout: 1.0)
    XCTAssertTrue(flushSucceeded.locking { $0 })

    _ = meterProvider.shutdown()
  }

  func testForceFlushReturnsExportResult() {
    let exporter = ResultMetricExporter(result: .failure)
    let reader = PeriodicMetricReaderSdk(exporter: exporter, exportInterval: exportInterval)
    let meterProvider = makeMeterProvider(reader: reader)
    let counter = meterProvider.meterBuilder(name: "meter").build().counterBuilder(name: "counter").build()

    counter.add(value: 1)
    XCTAssertEqual(reader.forceFlush(), .failure)

    _ = meterProvider.shutdown()
  }

  func testShutdownDrainsPendingExports() {
    let blockingExporter = CountingBlockingMetricExporter(aggregationTemporality: .delta)
    let reader = PeriodicMetricReaderSdk(exporter: blockingExporter, exportInterval: exportInterval)
    let meterProvider = makeMeterProvider(reader: reader)
    let counter = meterProvider.meterBuilder(name: "meter").build().counterBuilder(name: "counter").build()

    counter.add(value: 1)
    blockingExporter.waitUntilIsBlocked()

    let shutdownCompleted = expectation(description: "shutdown completed")
    let shutdownFinished = Locked(initialValue: false)
    let shutdownSucceeded = Locked(initialValue: false)
    flushQueue.async {
      shutdownSucceeded.locking { $0 = reader.shutdown() == .success }
      shutdownFinished.locking { $0 = true }
      shutdownCompleted.fulfill()
    }

    let stillBlocked = expectation(description: "shutdown still blocked")
    verifyQueue.async {
      Thread.sleep(forTimeInterval: 0.1)
      stillBlocked.fulfill()
    }
    wait(for: [stillBlocked], timeout: 0.2)
    XCTAssertFalse(shutdownFinished.locking { $0 })

    blockingExporter.unblock()
    wait(for: [shutdownCompleted], timeout: 1.0)
    XCTAssertTrue(shutdownSucceeded.locking { $0 })
    XCTAssertEqual(blockingExporter.exportCallCount, 1)
    XCTAssertTrue(blockingExporter.shutdownCalled)

    _ = meterProvider.shutdown()
  }

  func testEmptyCollectionSkipsExport() {
    let exporter = ResultMetricExporter(result: .success)
    let reader = PeriodicMetricReaderSdk(exporter: exporter, exportInterval: exportInterval)
    reader.register(registration: NoopMetricProducer())

    XCTAssertEqual(reader.forceFlush(), .success)
    XCTAssertEqual(exporter.exportCallCount, 0)

    _ = reader.shutdown()
  }

  func testForceFlushReturnsFailureWhenExportTimesOut() {
    let blockingExporter = CountingBlockingMetricExporter(aggregationTemporality: .delta)
    let reader = PeriodicMetricReaderSdk(
      exporter: blockingExporter,
      exportInterval: exportInterval,
      exportTimeout: 0.1
    )
    let meterProvider = makeMeterProvider(reader: reader)
    let counter = meterProvider.meterBuilder(name: "meter").build().counterBuilder(name: "counter").build()

    counter.add(value: 1)
    blockingExporter.waitUntilIsBlocked()

    let flushCompleted = expectation(description: "forceFlush completed")
    let flushResult = Locked(initialValue: ExportResult.success)
    flushQueue.async {
      flushResult.locking { $0 = reader.forceFlush() }
      flushCompleted.fulfill()
    }

    wait(for: [flushCompleted], timeout: 1.0)
    XCTAssertEqual(flushResult.locking { $0 }, .failure)

    blockingExporter.unblock()
    _ = meterProvider.shutdown()
  }

  func testShutdownReturnsFailureWhenExportTimesOut() {
    let blockingExporter = CountingBlockingMetricExporter(aggregationTemporality: .delta)
    let reader = PeriodicMetricReaderSdk(
      exporter: blockingExporter,
      exportInterval: exportInterval,
      exportTimeout: 0.1
    )
    let meterProvider = makeMeterProvider(reader: reader)
    let counter = meterProvider.meterBuilder(name: "meter").build().counterBuilder(name: "counter").build()

    counter.add(value: 1)
    blockingExporter.waitUntilIsBlocked()

    let shutdownCompleted = expectation(description: "shutdown completed")
    let shutdownResult = Locked(initialValue: ExportResult.success)
    flushQueue.async {
      shutdownResult.locking { $0 = reader.shutdown() }
      shutdownCompleted.fulfill()
    }

    wait(for: [shutdownCompleted], timeout: 1.0)
    XCTAssertEqual(shutdownResult.locking { $0 }, .failure)
    XCTAssertTrue(blockingExporter.shutdownCalled)

    blockingExporter.unblock()
    _ = meterProvider.shutdown()
  }

  private func makeMeterProvider(exporter: MetricExporter) -> MeterProviderSdk {
    let reader = PeriodicMetricReaderSdk(exporter: exporter, exportInterval: exportInterval)
    return makeMeterProvider(reader: reader)
  }

  private func makeMeterProvider(reader: PeriodicMetricReaderSdk) -> MeterProviderSdk {
    MeterProviderSdk.builder()
      .registerMetricReader(reader: reader)
      .registerView(
        selector: InstrumentSelectorBuilder().build(),
        view: View.builder().build()
      )
      .build()
  }
}

private final class CountingBlockingMetricExporter: MetricExporter, @unchecked Sendable {
  private let blockingExporter: BlockingMetricExporter
  private let exportCallCountState = Locked(initialValue: 0)
  private let shutdownCalledState = Locked(initialValue: false)

  var exportCallCount: Int {
    exportCallCountState.locking { $0 }
  }

  var shutdownCalled: Bool {
    shutdownCalledState.locking { $0 }
  }

  init(aggregationTemporality: AggregationTemporality) {
    blockingExporter = BlockingMetricExporter(aggregationTemporality: aggregationTemporality)
  }

  func export(metrics: [MetricData]) -> ExportResult {
    exportCallCountState.locking { $0 += 1 }
    return blockingExporter.export(metrics: metrics)
  }

  func waitUntilIsBlocked() {
    blockingExporter.waitUntilIsBlocked()
  }

  func unblock() {
    blockingExporter.unblock()
  }

  func flush() -> ExportResult {
    blockingExporter.flush()
  }

  func shutdown() -> ExportResult {
    shutdownCalledState.locking { $0 = true }
    return blockingExporter.shutdown()
  }

  func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    blockingExporter.getAggregationTemporality(for: instrument)
  }
}

private final class ResultMetricExporter: MetricExporter, @unchecked Sendable {
  private let result: ExportResult
  private let exportCallCountState = Locked(initialValue: 0)

  var exportCallCount: Int {
    exportCallCountState.locking { $0 }
  }

  init(result: ExportResult) {
    self.result = result
  }

  func export(metrics: [MetricData]) -> ExportResult {
    exportCallCountState.locking { $0 += 1 }
    return result
  }

  func flush() -> ExportResult {
    .success
  }

  func shutdown() -> ExportResult {
    .success
  }

  func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    .delta
  }
}

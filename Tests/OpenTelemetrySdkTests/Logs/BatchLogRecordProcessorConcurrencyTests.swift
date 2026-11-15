/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class BatchLogRecordProcessorConcurrencyTests: XCTestCase {

  // MARK: - Concurrent emit from multiple threads

  func testConcurrentEmit() {
    let totalRecords = 1000
    let threads = 10
    let recordsPerThread = totalRecords / threads
    let waitingExporter = WaitingLogRecordExporter(numberToWaitFor: totalRecords)
    nonisolated(unsafe) let processor = BatchLogRecordProcessor(
      logRecordExporter: waitingExporter,
      scheduleDelay: 0.1,
      maxQueueSize: totalRecords + 100,
      maxExportBatchSize: 100
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    nonisolated(unsafe) let logger = loggerProvider.get(instrumentationScopeName: "ConcurrencyTest")

    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.batch.emit", attributes: .concurrent)

    for _ in 0..<threads {
      group.enter()
      queue.async {
        for _ in 0..<recordsPerThread {
          logger.logRecordBuilder().emit()
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "All emit calls should complete")

    let exported = waitingExporter.waitForExport()
    XCTAssertEqual(exported?.count, totalRecords,
                   "All \(totalRecords) records should be exported without loss")
    _ = processor.shutdown()
  }

  // MARK: - Emit at max queue size (overflow behavior)

  func testEmitAtMaxQueueSize() {
    let maxQueueSize = 50
    let totalEmits = maxQueueSize + 50
    let countingExporter = CountingLogRecordExporter()
    nonisolated(unsafe) let processor = BatchLogRecordProcessor(
      logRecordExporter: countingExporter,
      scheduleDelay: 60,
      maxQueueSize: maxQueueSize,
      maxExportBatchSize: maxQueueSize
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    nonisolated(unsafe) let logger = loggerProvider.get(instrumentationScopeName: "ConcurrencyTest")

    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.batch.overflow", attributes: .concurrent)

    for _ in 0..<totalEmits {
      group.enter()
      queue.async {
        logger.logRecordBuilder().emit()
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Overflow emit should not crash or deadlock")

    processor.forceFlush()
    XCTAssertGreaterThan(countingExporter.exportedCount, 0, "Some records should be exported")
    XCTAssertLessThanOrEqual(countingExporter.exportedCount, totalEmits,
                             "Should not export more records than emitted")
    _ = processor.shutdown()
  }

  // MARK: - Concurrent emit and forceFlush

  func testConcurrentEmitAndForceFlush() {
    let countingExporter = CountingLogRecordExporter()
    nonisolated(unsafe) let processor = BatchLogRecordProcessor(
      logRecordExporter: countingExporter,
      scheduleDelay: 60,
      maxQueueSize: 2048,
      maxExportBatchSize: 100
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    nonisolated(unsafe) let logger = loggerProvider.get(instrumentationScopeName: "ConcurrencyTest")

    let emitters = 5
    let recordsPerEmitter = 100
    let flushers = 3
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.batch.emitFlush", attributes: .concurrent)

    for _ in 0..<emitters {
      group.enter()
      queue.async {
        for _ in 0..<recordsPerEmitter {
          logger.logRecordBuilder().emit()
        }
        group.leave()
      }
    }

    for _ in 0..<flushers {
      group.enter()
      queue.async {
        processor.forceFlush()
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent emit and flush should not crash or deadlock")

    processor.forceFlush()
    let total = emitters * recordsPerEmitter
    XCTAssertEqual(countingExporter.exportedCount, total,
                   "All \(total) records should be exported exactly once")
    _ = processor.shutdown()
  }

  // MARK: - Concurrent emit and shutdown

  func testConcurrentEmitAndShutdown() {
    let countingExporter = CountingLogRecordExporter()
    nonisolated(unsafe) let processor = BatchLogRecordProcessor(
      logRecordExporter: countingExporter,
      scheduleDelay: 60,
      maxQueueSize: 2048,
      maxExportBatchSize: 100
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    nonisolated(unsafe) let logger = loggerProvider.get(instrumentationScopeName: "ConcurrencyTest")

    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.batch.emitShutdown", attributes: .concurrent)

    for _ in 0..<50 {
      group.enter()
      queue.async {
        logger.logRecordBuilder().emit()
        group.leave()
      }
    }

    group.enter()
    queue.async {
      _ = processor.shutdown()
      group.leave()
    }

    waitForConcurrentWork(group, "Concurrent emit during shutdown should not crash or deadlock")
  }
}

// MARK: - Thread-safe counting exporter

private final class CountingLogRecordExporter: LogRecordExporter, @unchecked Sendable {
  private let lock = NSLock()
  private var _exportedCount = 0

  var exportedCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _exportedCount
  }

  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    lock.lock()
    _exportedCount += logRecords.count
    lock.unlock()
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval?) {}
}

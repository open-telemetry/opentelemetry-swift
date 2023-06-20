//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class BatchLogRecordProcessorTests : XCTestCase {
    let maxScheduleDelay = 1.0
    var mockExporter = LogRecordExporterMock()


    func testExport() {
        let waitingExporter = WaitingLogRecordExporter(numberToWaitFor: 2)
        let loggerProvider = LoggerProviderBuilder().with(processors: [BatchLogRecordProcessor(logRecordExporter: waitingExporter,scheduleDelay: maxScheduleDelay)]).build()
        let logger = loggerProvider.get(instrumentationScopeName: "BatchLogRecordProcessorTest")
        logger.logRecordBuilder().emit()
        logger.logRecordBuilder().emit()
        let exported = waitingExporter.waitForExport()
        XCTAssertEqual(exported?.count, 2)
    }
    
    
    func testBufferSize() {
        let waitingExporter = WaitingLogRecordExporter(numberToWaitFor: 6)
        let loggerProvider = LoggerProviderBuilder().with(processors: [BatchLogRecordProcessor(logRecordExporter: waitingExporter,scheduleDelay: maxScheduleDelay ,maxQueueSize: 6, maxExportBatchSize: 2)]).build()
        let logger = loggerProvider.get(instrumentationScopeName: "BatchLogRecordProcessorTest")
        logger.logRecordBuilder().emit()
        logger.logRecordBuilder().emit()
        logger.logRecordBuilder().emit()
        logger.logRecordBuilder().emit()
        logger.logRecordBuilder().emit()
        logger.logRecordBuilder().emit()
        let exported = waitingExporter.waitForExport()
        waitingExporter.shutdown()
        XCTAssertEqual(exported?.count, 6)
        XCTAssertGreaterThanOrEqual(waitingExporter.exporter.exportCalledTimes, 3)
    }
    
    func testMaxLimit() {
        let maxQueueSize = 8
        let waitingExporter = WaitingLogRecordExporter(numberToWaitFor: maxQueueSize)
        let processor = BatchLogRecordProcessor(logRecordExporter: waitingExporter,scheduleDelay: 10000,maxQueueSize: maxQueueSize, maxExportBatchSize: maxQueueSize/2)
        let loggerProvider = LoggerProviderBuilder().with(processors: [processor]).build()
        _ = loggerProvider.get(instrumentationScopeName: "BatchLogRecordProcessorTest")
        #warning("Unfinished test")
    }
    
    func testForceExport() {
        let waitingExporter = WaitingLogRecordExporter(numberToWaitFor: 1)
        let processor = BatchLogRecordProcessor(logRecordExporter: waitingExporter,scheduleDelay: 10000,maxQueueSize: 10000, maxExportBatchSize: 2000)
        let loggerProvider = LoggerProviderBuilder().with(processors: [processor]).build()
        let logger = loggerProvider.get(instrumentationScopeName: "BatchLogRecordProcessorTest")
        for _ in 0 ..< 100 {
            logger.logRecordBuilder().emit()
        }
        _ = processor.forceFlush()
        let exported = waitingExporter.waitForExport()
        XCTAssertEqual(exported?.count, 100)
        XCTAssertEqual(waitingExporter.exporter.exportCalledTimes, 1)
    }
    
    func testShutdownFlushes() {
        let waitingExporter = WaitingLogRecordExporter(numberToWaitFor: 1)
        let processor = BatchLogRecordProcessor(logRecordExporter: waitingExporter,scheduleDelay: 0)
        let loggerProvider = LoggerProviderBuilder().with(processors: [processor]).build()
        let logger = loggerProvider.get(instrumentationScopeName: "BatchLogRecordProcessorTest")

        logger.logRecordBuilder().emit()
        
        XCTAssertEqual(processor.shutdown(), .success)
        let exported = waitingExporter.waitForExport()
        XCTAssertEqual(exported?.count, 1)
        XCTAssertTrue(waitingExporter.shutDownCalled)        
    }
    
    func testQueueOverflow() {
        let maxQueuedLogs = 8
        let blockingExporter = BlockingLogRecordExporter()
        let waitingExporter = WaitingLogRecordExporter(numberToWaitFor: maxQueuedLogs)
        let processor = BatchLogRecordProcessor(logRecordExporter:MultiLogRecordExporter(logRecordExporters:[waitingExporter, blockingExporter]) ,scheduleDelay: maxScheduleDelay, maxQueueSize: maxQueuedLogs, maxExportBatchSize: maxQueuedLogs / 2)
        let loggerProvider = LoggerProviderBuilder().with(processors: [processor]).build()
        let logger = loggerProvider.get(instrumentationScopeName: "BatchLogRecordProcessorTest")
        logger.logRecordBuilder().emit()
        blockingExporter.waitUntilIsBlocked()
        for _ in 0 ..< maxQueuedLogs {
            logger.logRecordBuilder().emit()
        }
        
        for _ in 0 ..< 7 {
            logger.logRecordBuilder().emit()
        }
        
        blockingExporter.unblock()
        
        let exported = waitingExporter.waitForExport()
        XCTAssertEqual(exported?.count, 9)
    }
}


class BlockingLogRecordExporter: LogRecordExporter {
    
    let cond = NSCondition()
    
    enum State {
        case waitToBlock
        case blocked
        case unblocked
    }
    
    var state : State = .waitToBlock
    
    func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        cond.lock()
        while state != .unblocked {
            state = .blocked
            cond.broadcast()
            cond.wait()
        }
        cond.unlock()
        return .success
    }
    func waitUntilIsBlocked() {
        cond.lock()
        while state != .blocked {
            cond.wait()
        }
        cond.unlock()
    }
    func forceFlush() -> ExportResult {
        return .success
    }
    
    func shutdown() {
    
    }
    
    fileprivate func unblock() {
        cond.lock()
        state = .unblocked
        cond.unlock()
        cond.broadcast()
    }
}

class WaitingLogRecordExporter: LogRecordExporter {
    var logRecordList = [ReadableLogRecord]()
    public var exporter = LogRecordExporterMock()
    let cond = NSCondition()
    let numberToWaitFor: Int
    var shutDownCalled = false
    
    init(numberToWaitFor:Int) {
        self.numberToWaitFor = numberToWaitFor
    }
    
    func waitForExport() -> [ReadableLogRecord]? {
        var ret: [ReadableLogRecord]
        cond.lock()
        defer { cond.unlock()}
        while logRecordList.count < numberToWaitFor {
            cond.wait()
        }
        ret = logRecordList
        logRecordList.removeAll()
        return ret
    }
    
    func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        cond.lock()
        logRecordList.append(contentsOf: logRecords)
        let status = exporter.export(logRecords: logRecords)

        cond.unlock()
        cond.broadcast()
        return status
    }
    
    func forceFlush() -> ExportResult {
        exporter.forceFlush()
    }
    func shutdown() {
        shutDownCalled = true
        exporter.shutdown()
    }
}

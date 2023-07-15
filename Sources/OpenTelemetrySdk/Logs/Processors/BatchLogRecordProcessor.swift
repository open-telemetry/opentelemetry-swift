//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class BatchLogRecordProcessor : LogRecordProcessor {
    
    fileprivate var worker : BatchWorker
    
    public init(logRecordExporter: LogRecordExporter, scheduleDelay: TimeInterval = 5, exportTimeout: TimeInterval = 30, maxQueueSize: Int = 2048, maxExportBatchSize: Int = 512, willExportCallback: ((inout [ReadableLogRecord])->Void)? = nil) {
        worker = BatchWorker(logRecordExporter: logRecordExporter, scheduleDelay: scheduleDelay, exportTimeout: exportTimeout, maxQueueSize: maxQueueSize, maxExportBatchSize: maxExportBatchSize, willExportCallback: willExportCallback)
        
        worker.start()
    }
    
    public func onEmit(logRecord: ReadableLogRecord) {
        worker.emit(logRecord: logRecord)
    }
    
    public func forceFlush() -> ExportResult {
        forceFlush(timeout: nil)
        return .success
    }
    
    public func forceFlush(timeout: TimeInterval?) {
        worker.forceFlush(explicitTimeout: timeout)

    }

    
    public func shutdown() -> ExportResult {
        worker.cancel()
        worker.shutdown()
        return .success
    }
}

private class BatchWorker : Thread {
    let logRecordExporter : LogRecordExporter
    let scheduleDelay : TimeInterval
    let maxQueueSize : Int
    let maxExportBatchSize : Int
    let exportTimeout : TimeInterval
    let willExportCallback: ((inout [ReadableLogRecord])->Void)?
    let halfMaxQueueSize: Int
    private let cond = NSCondition()
    var logRecordList = [ReadableLogRecord]()
    var queue : OperationQueue
    
    init(logRecordExporter: LogRecordExporter,
         scheduleDelay: TimeInterval,
         exportTimeout: TimeInterval,
         maxQueueSize: Int,
         maxExportBatchSize: Int,
         willExportCallback: ((inout [ReadableLogRecord])->Void)?) {
    
        self.logRecordExporter = logRecordExporter
        self.scheduleDelay = scheduleDelay
        self.exportTimeout = exportTimeout
        self.maxExportBatchSize = maxExportBatchSize
        self.maxQueueSize = maxQueueSize
        self.willExportCallback = willExportCallback
        self.halfMaxQueueSize = maxQueueSize >> 1
        queue = OperationQueue()
        queue.name = "BatchWorker Queue"
        queue.maxConcurrentOperationCount = 1
    }
    
    func emit(logRecord: ReadableLogRecord) {
        cond.lock()
        defer { cond.unlock()}
        if logRecordList.count == maxQueueSize {
            // TODO: record a counter for dropped logs
            return
        }
        
        // TODO: record a gauge for referenced logs
        logRecordList.append(logRecord)
        if logRecordList.count >= halfMaxQueueSize {
            cond.broadcast()
        }
    }
    
    override func main() {
        repeat {
            maybeAutoreleasepool {
                var logRecordsCopy : [ReadableLogRecord]
                cond.lock()
                if logRecordList.count < maxExportBatchSize {
                    repeat {
                        cond.wait(until: Date().addingTimeInterval(scheduleDelay))
                    } while logRecordList.isEmpty
                }
                logRecordsCopy = logRecordList
                logRecordList.removeAll()
                cond.unlock()
                self.exportBatch(logRecordList: logRecordsCopy, explicitTimeout: nil)
            }
        } while true
    }
    
    public func forceFlush(explicitTimeout: TimeInterval?) {
        var logRecordsCopy: [ReadableLogRecord]
        cond.lock()
        logRecordsCopy = logRecordList
        logRecordList.removeAll()
        cond.unlock()
        
        exportBatch(logRecordList: logRecordsCopy, explicitTimeout: explicitTimeout)
    }
    
    
    public func shutdown() {
        forceFlush(explicitTimeout: nil)
        _ = logRecordExporter.shutdown()
    }
    
    private func exportBatch(logRecordList: [ReadableLogRecord], explicitTimeout: TimeInterval?) {
        let exportOperation = BlockOperation { [weak self] in
            self?.exportAction(logRecordList : logRecordList)
        }
        let timeoutTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timeoutTimer.setEventHandler { exportOperation.cancel() }
        let maxTimeOut = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, exportTimeout)
        timeoutTimer.schedule(deadline: .now() + .milliseconds(Int(maxTimeOut.toMilliseconds)), leeway: .milliseconds(1))
        timeoutTimer.activate()
        queue.addOperation(exportOperation)
        queue.waitUntilAllOperationsAreFinished()
        timeoutTimer.cancel()
    }
    
    private func exportAction(logRecordList: [ReadableLogRecord])  {
        stride(from: 0, to: logRecordList.endIndex, by: maxExportBatchSize).forEach {
            var logRecordToExport = logRecordList[$0 ..< min($0 + maxExportBatchSize, logRecordList.count)].map {$0}
            willExportCallback?(&logRecordToExport)
            _ = logRecordExporter.export(logRecords: logRecordToExport)
        }
    }
}


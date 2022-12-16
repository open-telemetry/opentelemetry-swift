//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class MultiLogRecordProcessor : LogRecordProcessor {
    var logRecordProcessors = [LogRecordProcessor]()

    public func forceFlush() -> ExportResult {
        var result : ExportResult = .success
        logRecordProcessors.forEach {
            result.mergeResultCode(newResultCode: $0.forceFlush())
        }
        return result
    }
    
    public func shutdown() -> ExportResult {
        var result : ExportResult = .success
        logRecordProcessors.forEach {
            result.mergeResultCode(newResultCode: $0.shutdown())
        }
        return result
    }
    
    public init(logRecordProcessors: [LogRecordProcessor]){
        self.logRecordProcessors = logRecordProcessors
    }
    
    public func onEmit(logRecord: ReadableLogRecord) {
        logRecordProcessors.forEach {
            $0.onEmit(logRecord: logRecord)
        }
    }
    
    
}

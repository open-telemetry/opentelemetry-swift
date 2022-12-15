//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public class MultiLogRecordExporter : LogRecordExporter {
    var logRecordExporters : [LogRecordExporter]

    public init(logRecordExporters: [LogRecordExporter]) {
        self.logRecordExporters = logRecordExporters
    }
    
    public func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        var result = ExportResult.success
        logRecordExporters.forEach {
            result.mergeResultCode(newResultCode: $0.export(logRecords: logRecords))
        }
        return result
    }
    
    public func shutdown() {
        logRecordExporters.forEach {
            $0.shutdown()
        }
    }
    
    public func forceFlush() -> ExportResult {
        var result = ExportResult.success
        logRecordExporters.forEach {
            result.mergeResultCode(newResultCode: $0.forceFlush())
        }
        return result
    }
    
    
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetrySdk

class LogRecordExporterMock : LogRecordExporter {
    var exportCalledTimes : Int = 0
    var exportCalledData : [ReadableLogRecord]?
    
    var shutdownCalledTimes : Int = 0
    
    var forceFlushCalledTimes : Int = 0
    var returnValue: ExportResult = .success
    
    func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord]) -> OpenTelemetrySdk.ExportResult {
        exportCalledTimes += 1
        exportCalledData = logRecords
        return returnValue
    }
    
    func shutdown() {
        shutdownCalledTimes += 1
    }
    
    func forceFlush() -> OpenTelemetrySdk.ExportResult {
        forceFlushCalledTimes += 1
        return returnValue
    }
    
    
}

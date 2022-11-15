//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public class SimpleLogRecordProcessor : LogRecordProcessor {
    private let logRecordExporter : LogRecordExporter
    
    public init(logRecordExporter: LogRecordExporter) {
        self.logRecordExporter = logRecordExporter
    }
    
    public func onEmit(logRecord: ReadableLogRecord) {
        _ = logRecordExporter.export(logRecords: [logRecord])
    }
    
    public func forceFlush() -> ExportResult {
        return logRecordExporter.forceFlush()
    }
    
    public func shutdown() -> ExportResult {
         logRecordExporter.shutdown()
        return .success
    }
    
    
}

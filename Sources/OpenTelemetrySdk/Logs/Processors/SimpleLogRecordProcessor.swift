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
        _ = logRecordExporter.export(logRecords: [logRecord], explicitTimeout: nil)
    }
    
  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
        return logRecordExporter.forceFlush(explicitTimeout: explicitTimeout)
    }
    
  public func shutdown(explicitTimeout: TimeInterval? = nil) -> ExportResult {
         logRecordExporter.shutdown(explicitTimeout: explicitTimeout)
        return .success
    }
    
    
}

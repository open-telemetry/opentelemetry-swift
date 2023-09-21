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
  
  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> ExportResult {
    var result = ExportResult.success
    logRecordExporters.forEach {
      result.mergeResultCode(newResultCode: $0.export(logRecords: logRecords, explicitTimeout: explicitTimeout))
    }
    return result
  }
  
  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    logRecordExporters.forEach {
      $0.shutdown(explicitTimeout: explicitTimeout)
    }
  }
  
  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    var result = ExportResult.success
    logRecordExporters.forEach {
      result.mergeResultCode(newResultCode: $0.forceFlush(explicitTimeout: explicitTimeout))
    }
    return result
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public final class MultiLogRecordExporter: LogRecordExporter {
  let logRecordExporters: [LogRecordExporter]

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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension MultiLogRecordExporter {
  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) async -> ExportResult {
    await withTaskGroup(of: ExportResult.self, returning: ExportResult.self) { group in
      for exporter in logRecordExporters {
        group.addTask {
          await exporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
        }
      }
      var result = ExportResult.success
      for await exportResult in group {
        result.mergeResultCode(newResultCode: exportResult)
      }
      return result
    }
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) async {
    await withTaskGroup(of: Void.self) { group in
      for exporter in logRecordExporters {
        group.addTask {
          await exporter.shutdown(explicitTimeout: explicitTimeout)
        }
      }
    }
  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) async -> ExportResult {
    await withTaskGroup(of: ExportResult.self, returning: ExportResult.self) { group in
      for exporter in logRecordExporters {
        group.addTask {
          await exporter.forceFlush(explicitTimeout: explicitTimeout)
        }
      }
      var result = ExportResult.success
      for await exportResult in group {
        result.mergeResultCode(newResultCode: exportResult)
      }
      return result
    }
  }
}

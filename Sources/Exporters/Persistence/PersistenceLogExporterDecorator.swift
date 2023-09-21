//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetrySdk

// a persistence exporter decorator for `LogRecords`.
// specialization of `PersistenceExporterDecorator` for `MetricExporter`.
public class PersistenceLogExporterDecorator: LogRecordExporter {

  struct LogRecordDecoratedExporter: DecoratedExporter {

    typealias SignalType = ReadableLogRecord

    private let logRecordExporter: LogRecordExporter

    init(logRecordExporter: LogRecordExporter) {
      self.logRecordExporter = logRecordExporter
    }

    func export(values: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> DataExportStatus {
      let result = logRecordExporter.export(logRecords: values, explicitTimeout: explicitTimeout)
      return DataExportStatus(needsRetry: result == .failure)
    }
  }
  private let logRecordExporter: LogRecordExporter
  private let persistenceExporter: PersistenceExporterDecorator<LogRecordDecoratedExporter>

  public init(
    logRecordExporter: LogRecordExporter,
    storageURL: URL,
    exportCondition: @escaping () -> Bool = { true },
    performancePreset: PersistencePerformancePreset = .default
  ) throws {
    self.persistenceExporter =
      PersistenceExporterDecorator<LogRecordDecoratedExporter>(
        decoratedExporter: LogRecordDecoratedExporter(logRecordExporter: logRecordExporter),
        storageURL: storageURL,
        exportCondition: exportCondition,
        performancePreset: performancePreset)
    self.logRecordExporter = logRecordExporter
  }

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
    do {
      try persistenceExporter.export(values: logRecords)
      return .success
    } catch {
      return .failure
    }
  }

  public func shutdown(explicitTimeout: TimeInterval?) {
    persistenceExporter.flush()
    logRecordExporter.shutdown(explicitTimeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    persistenceExporter.flush()
    return logRecordExporter.forceFlush(explicitTimeout: explicitTimeout)

  }
}

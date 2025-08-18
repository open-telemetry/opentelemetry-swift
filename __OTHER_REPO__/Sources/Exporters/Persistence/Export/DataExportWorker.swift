/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

// a protocol for an exporter of `Data` to which a `DataExportWorker` can delegate persisted
// data export
protocol DataExporter {
  func export(data: Data) -> DataExportStatus
}

// a protocol needed for mocking `DataExportWorker`
protocol DataExportWorkerProtocol {
  func flush() -> Bool
}

class DataExportWorker: DataExportWorkerProtocol {
  /// Queue to execute exports.
  let queue = DispatchQueue(label: "com.otel.persistence.dataExportWorker", target: .global(qos: .utility))
  /// File reader providing data to export.
  private let fileReader: FileReader
  /// Data exporter sending data to server.
  private let dataExporter: DataExporter
  /// Variable system conditions determining if export should be performed.
  private let exportCondition: () -> Bool

  /// Delay used to schedule consecutive exports.
  private var delay: Delay

  /// Export work scheduled by this worker.
  private var exportWork: DispatchWorkItem?

  init(fileReader: FileReader,
       dataExporter: DataExporter,
       exportCondition: @escaping () -> Bool,
       delay: Delay) {
    self.fileReader = fileReader
    self.exportCondition = exportCondition
    self.dataExporter = dataExporter
    self.delay = delay

    let exportWork = DispatchWorkItem { [weak self] in
      guard let self else {
        return
      }

      let isSystemReady = self.exportCondition()
      let nextBatch = isSystemReady ? self.fileReader.readNextBatch() : nil
      if let batch = nextBatch {
        // Export batch
        let exportStatus = self.dataExporter.export(data: batch.data)

        // Delete or keep batch depending on the export status
        if exportStatus.needsRetry {
          self.delay.increase()
        } else {
          self.fileReader.markBatchAsRead(batch)
          self.delay.decrease()
        }
      } else {
        self.delay.increase()
      }

      scheduleNextExport(after: self.delay.current)
    }

    self.exportWork = exportWork

    scheduleNextExport(after: self.delay.current)
  }

  private func scheduleNextExport(after delay: TimeInterval) {
    guard let work = exportWork else {
      return
    }

    queue.asyncAfter(deadline: .now() + delay, execute: work)
  }

  /// This method  gets remaining files at once, and exports them
  /// It assures that periodic exporter cannot read or export the files while the flush is being processed
  func flush() -> Bool {
    let success = queue.sync {
      self.fileReader.onRemainingBatches {
        let exportStatus = self.dataExporter.export(data: $0.data)
        if !exportStatus.needsRetry {
          self.fileReader.markBatchAsRead($0)
        }
      }
    }
    return success
  }

  /// Cancels scheduled exports and stops scheduling next ones.
  /// - It does not affect the export that has already begun.
  /// - It blocks the caller thread if called in the middle of export execution.
  func cancelSynchronously() {
    queue.sync(flags: .barrier) {
      // This cancellation must be performed on the `queue` to ensure that it is not called
      // in the middle of a `DispatchWorkItem` execution - otherwise, as the pending block would be
      // fully executed, it will schedule another export by calling `nextScheduledWork(after:)` at the end.
      self.exportWork?.cancel()
      self.exportWork = nil
    }
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct Batch {
  /// Data read from file, prefixed with `[` and suffixed with `]`.
  let data: Data
  /// File from which `data` was read.
  fileprivate let file: ReadableFile
}

final class FileReader {
  /// Data reading format.
  private let dataFormat: DataFormat
  /// Orchestrator producing reference to readable file.
  private let orchestrator: FilesOrchestrator
  /// Files marked as read.
  private var filesRead: [ReadableFile] = []

  init(dataFormat: DataFormat, orchestrator: FilesOrchestrator) {
    self.dataFormat = dataFormat
    self.orchestrator = orchestrator
  }

  // MARK: - Reading batches

  func readNextBatch() -> Batch? {
    if let file = orchestrator.getReadableFile(excludingFilesNamed: Set(filesRead.map(\.name))) {
      do {
        let fileData = try file.read()
        let batchData = dataFormat.prefixData + fileData + dataFormat.suffixData
        return Batch(data: batchData, file: file)
      } catch {
        print("Failed to read data from file")
        return nil
      }
    }

    return nil
  }

  /// This method  gets remaining files at once, and process each file after with the block passed.
  /// Currently called from flush method
  func onRemainingBatches(process: (Batch) -> Void) -> Bool {
    do {
      try orchestrator.getAllFiles(excludingFilesNamed: Set(filesRead.map(\.name)))?.forEach {
        let fileData = try $0.read()
        let batchData = dataFormat.prefixData + fileData + dataFormat.suffixData
        process(Batch(data: batchData, file: $0))
      }
    } catch {
      return false
    }
    return true
  }

  // MARK: - Accepting batches

  func markBatchAsRead(_ batch: Batch) {
    orchestrator.delete(readableFile: batch.file)
    filesRead.append(batch.file)
  }
}

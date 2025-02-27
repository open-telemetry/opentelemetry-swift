/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct Batch {
  /// Data read from file
  let data: Data
  /// File from which `data` was read.
  let file: ReadableFile
}

protocol FileReader {
  func readNextBatch() -> Batch?

  func onRemainingBatches(process: (Batch) -> Void) -> Bool

  func markBatchAsRead(_ batch: Batch)
}

final class OrchestratedFileReader: FileReader {
  /// Orchestrator producing reference to readable file.
  private let orchestrator: FilesOrchestrator

  /// Files marked as read.
  private var filesRead: [ReadableFile] = []

  init(orchestrator: FilesOrchestrator) {
    self.orchestrator = orchestrator
  }

  // MARK: - Reading batches

  func readNextBatch() -> Batch? {
    if let file = orchestrator.getReadableFile(excludingFilesNamed: Set(filesRead.map(\.name))) {
      do {
        let fileData = try file.read()
        return Batch(data: fileData, file: file)
      } catch {
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
        process(Batch(data: fileData, file: $0))
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

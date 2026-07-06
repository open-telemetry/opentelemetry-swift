/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

struct Batch: Sendable {
  /// Data read from file
  let data: Data
  /// File from which `data` was read.
  let file: ReadableFile
}

protocol FileReader: Sendable {
  func readNextBatch() -> Batch?

  func onRemainingBatches(process: (Batch) -> Void) -> Bool

  func markBatchAsRead(_ batch: Batch)
}

final class OrchestratedFileReader: FileReader {
  /// Orchestrator producing reference to readable file.
  private let orchestrator: FilesOrchestrator

  /// Files marked as read.
  private let filesRead = Locked(initialValue: [ReadableFile]())

  init(orchestrator: FilesOrchestrator) {
    self.orchestrator = orchestrator
  }

  // MARK: - Reading batches

  func readNextBatch() -> Batch? {
    let excludedFileNames = filesRead.locking { Set($0.map(\.name)) }
    if let file = orchestrator.getReadableFile(excludingFilesNamed: excludedFileNames) {
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
      let excludedFileNames = filesRead.locking { Set($0.map(\.name)) }
      try orchestrator.getAllFiles(excludingFilesNamed: excludedFileNames)?.forEach {
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
    filesRead.locking { $0.append(batch.file) }
  }
}

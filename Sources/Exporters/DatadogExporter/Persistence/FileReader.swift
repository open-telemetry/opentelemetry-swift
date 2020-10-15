// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

internal struct Batch {
    /// Data read from file, prefixed with `[` and suffixed with `]`.
    let data: Data
    /// File from which `data` was read.
    fileprivate let file: ReadableFile
}

internal final class FileReader {
    /// Data reading format.
    private let dataFormat: DataFormat
    /// Orchestrator producing reference to readable file.
    private let orchestrator: FilesOrchestrator
    /// Queue used to synchronize files access (read / write).
    private let queue: DispatchQueue

    /// Files marked as read.
    private var filesRead: [ReadableFile] = []

    init(dataFormat: DataFormat, orchestrator: FilesOrchestrator, queue: DispatchQueue) {
        self.dataFormat = dataFormat
        self.orchestrator = orchestrator
        self.queue = queue
    }

    // MARK: - Reading batches

    func readNextBatch() -> Batch? {
        queue.sync {
            synchronizedReadNextBatch()
        }
    }

    private func synchronizedReadNextBatch() -> Batch? {
        if let file = orchestrator.getReadableFile(excludingFilesNamed: Set(filesRead.map { $0.name })) {
            do {
                let fileData = try file.read()
                let batchData = dataFormat.prefixData + fileData + dataFormat.suffixData
                return Batch(data: batchData, file: file)
            } catch {
                print("🔥 Failed to read file: \(error)")
                return nil
            }
        }

        return nil
    }

    /// This method  gets remaining files at once, and process each file after with the block passed.
    /// Being on a queue assures that no other previous batches are uploaded while these are being handled
    internal func onRemainingBatches(process: (Batch)->()) -> Bool {
        queue.sync {
            do {
                try orchestrator.getAllFiles(excludingFilesNamed: Set(filesRead.map { $0.name }))?.forEach {
                    let fileData = try $0.read()
                    let batchData = dataFormat.prefixData + fileData + dataFormat.suffixData
                    process(Batch(data: batchData, file: $0))
                }
            } catch {
                return false
            }
            return true
        }
    }

    // MARK: - Accepting batches

    func markBatchAsRead(_ batch: Batch) {
        queue.sync { [weak self] in
            self?.synchronizedMarkBatchAsRead(batch)
        }
    }

    func synchronizedMarkBatchAsRead(_ batch: Batch) {
        orchestrator.delete(readableFile: batch.file)
        filesRead.append(batch.file)
    }
}

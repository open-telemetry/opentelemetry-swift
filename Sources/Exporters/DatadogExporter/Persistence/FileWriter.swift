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

internal final class FileWriter {
    /// Data writting format.
    private let dataFormat: DataFormat
    /// Orchestrator producing reference to writable file.
    private let orchestrator: FilesOrchestrator
    /// JSON encoder used to encode data.
    private let jsonEncoder: JSONEncoder
    /// Queue used to synchronize files access (read / write) and perform decoding on background thread.
    // Temporarily internal so tests can wait for the writer to finish before exiting
    internal let queue: DispatchQueue

    init(dataFormat: DataFormat, orchestrator: FilesOrchestrator, queue: DispatchQueue) {
        self.dataFormat = dataFormat
        self.orchestrator = orchestrator
        self.queue = queue
        self.jsonEncoder = JSONEncoder.default()
    }

    // MARK: - Writing data
    /// Encodes given value to JSON data and writes it to file.
    /// Comma is used to separate consecutive values in the file.

    func write<T: Encodable>(value: T) {
        queue.async { [weak self] in
            self?.synchronizedWrite(value: value)
        }
    }

    func writeSync<T: Encodable>(value: T) {
        queue.sync { [weak self] in
            self?.synchronizedWrite(value: value, syncOnEnd: true)
        }
    }

    private func synchronizedWrite<T: Encodable>(value: T, syncOnEnd: Bool = false) {
        do {
            let data = try jsonEncoder.encode(value)
            let file = try orchestrator.getWritableFile(writeSize: UInt64(data.count))

            if try file.size() == 0 {
                try file.append(data: data, synchronized: syncOnEnd)
            } else {
                let atomicData = dataFormat.separatorData + data
                try file.append(data: atomicData, synchronized: syncOnEnd)
            }
        } catch {
            print("🔥 Failed to write file: \(error)")
        }
    }
}

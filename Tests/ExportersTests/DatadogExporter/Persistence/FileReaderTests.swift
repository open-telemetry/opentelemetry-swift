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

@testable import DatadogExporter
import XCTest

class FileReaderTests: XCTestCase {
    private let queue = DispatchQueue(label: "dd-tests-read", target: .global(qos: .utility))

    override func setUp() {
        super.setUp()
        temporaryDirectory.create()
    }

    override func tearDown() {
        temporaryDirectory.delete()
        super.tearDown()
    }

    func testItReadsSingleBatch() throws {
        let reader = FileReader(
            dataFormat: .mockWith(prefix: "[", suffix: "]"),
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: StoragePerformanceMock.readAllFiles,
                dateProvider: SystemDateProvider()
            ),
            queue: queue
        )
        _ = try temporaryDirectory
            .createFile(named: Date.mockAny().toFileName)
            .append(data: "ABCD".utf8Data)

        XCTAssertEqual(try temporaryDirectory.files().count, 1)
        let batch = reader.readNextBatch()

        XCTAssertEqual(batch?.data, "[ABCD]".utf8Data)
    }

    func testItMarksBatchesAsRead() throws {
        let dateProvider = RelativeDateProvider(advancingBySeconds: 60)
        let reader = FileReader(
            dataFormat: .mockWith(prefix: "[", suffix: "]"),
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: StoragePerformanceMock.readAllFiles,
                dateProvider: dateProvider
            ),
            queue: queue
        )
        let file1 = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)
        try file1.append(data: "1".utf8Data)

        let file2 = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)
        try file2.append(data: "2".utf8Data)

        let file3 = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)
        try file3.append(data: "3".utf8Data)

        var batch: Batch
        batch = try reader.readNextBatch().unwrapOrThrow()
        XCTAssertEqual(batch.data, "[1]".utf8Data)
        reader.markBatchAsRead(batch)

        batch = try reader.readNextBatch().unwrapOrThrow()
        XCTAssertEqual(batch.data, "[2]".utf8Data)
        reader.markBatchAsRead(batch)

        batch = try reader.readNextBatch().unwrapOrThrow()
        XCTAssertEqual(batch.data, "[3]".utf8Data)
        reader.markBatchAsRead(batch)

        XCTAssertNil(reader.readNextBatch())
        XCTAssertEqual(try temporaryDirectory.files().count, 0)
    }
}

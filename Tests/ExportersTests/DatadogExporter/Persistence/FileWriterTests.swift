/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class FileWriterTests: XCTestCase {
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  override func setUp() {
    super.setUp()
    temporaryDirectory.create()
  }

  override func tearDown() {
    temporaryDirectory.delete()
    super.tearDown()
  }

  func testItWritesDataToSingleFile() throws {
    let expectation = expectation(description: "write completed")
    let writer = FileWriter(dataFormat: DataFormat(prefix: "[", suffix: "]", separator: ","),
                            orchestrator: FilesOrchestrator(directory: temporaryDirectory,
                                                            performance: PerformancePreset.default,
                                                            dateProvider: SystemDateProvider()))

    writer.write(value: ["key1": "value1"])
    writer.write(value: ["key2": "value3"])
    writer.write(value: ["key3": "value3"])

    waitForWritesCompletion(on: writer.queue, thenFulfill: expectation)
    waitForExpectations(timeout: 1, handler: nil)
    XCTAssertEqual(try temporaryDirectory.files().count, 1)
    XCTAssertEqual(try temporaryDirectory.files()[0].read(),
                   #"{"key1":"value1"},{"key2":"value3"},{"key3":"value3"}"#.utf8Data)
  }

  func testGivenErrorVerbosity_whenIndividualDataExceedsMaxWriteSize_itDropsDataAndPrintsError() throws {
    let expectation1 = expectation(description: "write completed")
    let expectation2 = expectation(description: "second write completed")

    let writer = FileWriter(dataFormat: .mockWith(prefix: "[", suffix: "]"),
                            orchestrator: FilesOrchestrator(directory: temporaryDirectory,
                                                            performance: StoragePerformanceMock(maxFileSize: .max,
                                                                                                maxDirectorySize: .max,
                                                                                                maxFileAgeForWrite: .distantFuture,
                                                                                                minFileAgeForRead: .mockAny(),
                                                                                                maxFileAgeForRead: .mockAny(),
                                                                                                maxObjectsInFile: .max,
                                                                                                maxObjectSize: 17 // 17 bytes is enough to write {"key1":"value1"} JSON
                                                            ),
                                                            dateProvider: SystemDateProvider()))

    writer.write(value: ["key1": "value1"]) // will be written

    waitForWritesCompletion(on: writer.queue, thenFulfill: expectation1)
    wait(for: [expectation1], timeout: 1)
    XCTAssertEqual(try temporaryDirectory.files()[0].read(), #"{"key1":"value1"}"#.utf8Data)

    writer.write(value: ["key2": "value3 that makes it exceed 17 bytes"]) // will be dropped

    waitForWritesCompletion(on: writer.queue, thenFulfill: expectation2)
    wait(for: [expectation2], timeout: 1)
    XCTAssertEqual(try temporaryDirectory.files()[0].read(), #"{"key1":"value1"}"#.utf8Data) // same content as before
  }

  /// NOTE: Test added after incident-4797
  /// NOTE 2: Test disabled after random failures/successes
//    func testWhenIOExceptionsHappenRandomly_theFileIsNeverMalformed() throws {
//        let expectation = self.expectation(description: "write completed")
//        let writer = FileWriter(
//            dataFormat: DataFormat(prefix: "[", suffix: "]", separator: ","),
//            orchestrator: FilesOrchestrator(
//                directory: temporaryDirectory,
//                performance: StoragePerformanceMock(
//                    maxFileSize: .max,
//                    maxDirectorySize: .max,
//                    maxFileAgeForWrite: .distantFuture, // write to single file
//                    minFileAgeForRead: .distantFuture,
//                    maxFileAgeForRead: .distantFuture,
//                    maxObjectsInFile: .max, // write to single file
//                    maxObjectSize: .max
//                ),
//                dateProvider: SystemDateProvider()
//            )
//        )
//
//        let ioInterruptionQueue = DispatchQueue(label: "com.datadohq.file-writer-random-io")
//
//        func randomlyInterruptIO(for file: File?) {
//            ioInterruptionQueue.async { try? file?.makeReadonly() }
//            ioInterruptionQueue.async { try? file?.makeReadWrite() }
//        }
//
//        struct Foo: Codable {
//            var foo = "bar"
//        }
//
//        // Write 300 of `Foo`s and interrupt writes randomly
//        (0..<300).forEach { _ in
//            writer.write(value: Foo())
//            randomlyInterruptIO(for: try? temporaryDirectory.files().first)
//        }
//
//        ioInterruptionQueue.sync {}
//        waitForWritesCompletion(on: writer.queue, thenFulfill: expectation)
//        waitForExpectations(timeout: 10, handler: nil)
//        XCTAssertEqual(try temporaryDirectory.files().count, 1)
//
//        let fileData = try temporaryDirectory.files()[0].read()
//        let jsonDecoder = JSONDecoder()
//
//        // Assert that data written is not malformed
//        let writtenData = try jsonDecoder.decode([Foo].self, from: "[".utf8Data + fileData + "]".utf8Data)
//        // Assert that some (including all) `Foo`s were written
//        XCTAssertGreaterThan(writtenData.count, 0)
//        XCTAssertLessThanOrEqual(writtenData.count, 300)
//    }

  private func waitForWritesCompletion(on queue: DispatchQueue, thenFulfill expectation: XCTestExpectation) {
    queue.async { expectation.fulfill() }
  }
}

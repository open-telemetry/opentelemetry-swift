/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import XCTest

class OrchestratedFileWriterTests: XCTestCase {
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
    let writer = OrchestratedFileWriter(
      orchestrator: FilesOrchestrator(directory: temporaryDirectory,
                                      performance: PersistencePerformancePreset.default,
                                      dateProvider: SystemDateProvider())
    )

    var data = Data()

    var value = "value1"
    writer.write(data: value.utf8Data)
    data.append(value.utf8Data)

    value = "value2"
    writer.write(data: value.utf8Data)
    data.append(value.utf8Data)

    value = "value3"
    writer.write(data: value.utf8Data)
    data.append(value.utf8Data)

    waitForWritesCompletion(on: writer.queue, thenFulfill: expectation)
    waitForExpectations(timeout: 1, handler: nil)
    XCTAssertEqual(try temporaryDirectory.files().count, 1)
    XCTAssertEqual(try temporaryDirectory.files()[0].read(), data)
  }

  func testGivenErrorVerbosity_whenIndividualDataExceedsMaxWriteSize_itDropsDataAndPrintsError() throws {
    let expectation1 = expectation(description: "write completed")
    let expectation2 = expectation(description: "second write completed")

    let writer = OrchestratedFileWriter(
      orchestrator: FilesOrchestrator(directory: temporaryDirectory,
                                      performance: StoragePerformanceMock(maxFileSize: .max,
                                                                          maxDirectorySize: .max,
                                                                          maxFileAgeForWrite: .distantFuture,
                                                                          minFileAgeForRead: .mockAny(),
                                                                          maxFileAgeForRead: .mockAny(),
                                                                          maxObjectsInFile: .max,
                                                                          maxObjectSize: 17 // 17 bytes is enough to write {"key1":"value1"} JSON
                                      ),
                                      dateProvider: SystemDateProvider())
    )

    writer.write(data: "value1".utf8Data) // will be written

    waitForWritesCompletion(on: writer.queue, thenFulfill: expectation1)
    wait(for: [expectation1], timeout: 1)
    XCTAssertEqual(try temporaryDirectory.files()[0].read(), "value1".utf8Data)

    writer.write(data: "value2 that makes it exceed 17 bytes".utf8Data) // will be dropped

    waitForWritesCompletion(on: writer.queue, thenFulfill: expectation2)
    wait(for: [expectation2], timeout: 1)
    XCTAssertEqual(try temporaryDirectory.files()[0].read(), "value1".utf8Data) // same content as before
  }

  /// NOTE: Test added after incident-4797
  /// NOTE 2: Test disabled after random failures/successes
//    func testWhenIOExceptionsHappenRandomly_theFileIsNeverMalformed() throws {
//        let expectation = self.expectation(description: "write completed")
//        let writer = OrchestratedFileWriter(
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
//        let ioInterruptionQueue = DispatchQueue(label: "com.otel.persistence.file-writer-random-io")
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
//        let jsonEncoder = JSONEncoder()
//
//        // Write 300 of `Foo`s and interrupt writes randomly
//        try (0..<300).forEach { _ in
//            var fooData = try jsonEncoder.encode(Foo())
//            fooData.append(",".utf8Data)
//            writer.write(data: fooData)
//            randomlyInterruptIO(for: try? temporaryDirectory.files().first)
//        }
//
//        ioInterruptionQueue.sync {}
//        waitForWritesCompletion(on: writer.queue, thenFulfill: expectation)
//        waitForExpectations(timeout: 7, handler: nil)
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

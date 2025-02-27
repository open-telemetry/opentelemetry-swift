/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import XCTest

class DataExportWorkerTests: XCTestCase {
  lazy var dateProvider = RelativeDateProvider(advancingBySeconds: 1)

  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  // MARK: - Data Exports

  func testItExportsAllData() {
    let v1ExportExpectation = expectation(description: "V1 exported")
    let v2ExportExpectation = expectation(description: "V2 exported")
    let v3ExportExpectation = expectation(description: "V3 exported")

    var mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: false))

    mockDataExporter.onExport = { data in
      switch data.utf8String {
      case "v1": v1ExportExpectation.fulfill()
      case "v2": v2ExportExpectation.fulfill()
      case "v3": v3ExportExpectation.fulfill()
      default: break
      }
    }

    // Given
    let fileReader = FileReaderMock()
    fileReader.addFile(name: "1", data: "v1".utf8Data)
    fileReader.addFile(name: "2", data: "v2".utf8Data)
    fileReader.addFile(name: "3", data: "v3".utf8Data)

    // When
    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { true },
                                  delay: DataExportDelay(performance: ExportPerformanceMock.veryQuick))

    // Then
    waitForExpectations(timeout: 1, handler: nil)

    worker.cancelSynchronously()

    XCTAssertEqual(fileReader.files.count, 0)
  }

  func testGivenDataToExport_whenExportFinishesAndDoesNotNeedToBeRetried_thenDataIsDeleted() {
    let startExportExpectation = expectation(description: "Export has started")

    var mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: false))
    mockDataExporter.onExport = { _ in startExportExpectation.fulfill() }

    // Given
    let fileReader = FileReaderMock()
    fileReader.addFile(name: "file", data: "value".utf8Data)

    // When
    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { true },
                                  delay: DataExportDelay(performance: ExportPerformanceMock.veryQuick))

    wait(for: [startExportExpectation], timeout: 0.5)

    worker.cancelSynchronously()

    // Then
    XCTAssertEqual(fileReader.files.count, 0, "When export finishes with `needsRetry: false`, data should be deleted")
  }

  func testGivenDataToExport_whenExportFinishesAndNeedsToBeRetried_thenDataIsPreserved() {
    let startExportExpectation = expectation(description: "Export has started")

    var mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: true))
    mockDataExporter.onExport = { _ in startExportExpectation.fulfill() }

    // Given
    let fileReader = FileReaderMock()
    fileReader.addFile(name: "file", data: "value".utf8Data)

    // When
    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { true },
                                  delay: DataExportDelay(performance: ExportPerformanceMock.veryQuick))

    wait(for: [startExportExpectation], timeout: 0.5)
    worker.cancelSynchronously()

    // Then
    XCTAssertEqual(fileReader.files.count, 1, "When export finishes with `needsRetry: true`, data should be preserved")
  }

  // MARK: - Export Interval Changes

  func testWhenThereIsNoBatch_thenIntervalIncreases() {
    let delayChangeExpectation = expectation(description: "Export delay is increased")
    let mockDelay = MockDelay { command in
      if case .increase = command {
        delayChangeExpectation.fulfill()
      } else {
        XCTFail("Wrong command is sent!")
      }
    }

    // When
    let fileReader = FileReaderMock()
    let mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: false))

    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { false },
                                  delay: mockDelay)

    // Then
    waitForExpectations(timeout: 1, handler: nil)
    worker.cancelSynchronously()
  }

  func testWhenBatchFails_thenIntervalIncreases() {
    let delayChangeExpectation = expectation(description: "Export delay is increased")
    let mockDelay = MockDelay { command in
      if case .increase = command {
        delayChangeExpectation.fulfill()
      } else {
        XCTFail("Wrong command is sent!")
      }
    }

    let exportExpectation = expectation(description: "value exported")

    // The onExport closure is called more than once as part of test execution
    // It does not seem to be called the same number of times on each test run.
    // Setting `assertForOverFulfill` to `false` works around the XCTestExpectation
    // error that fails the test.
    // "API violation - multiple calls made to -[XCTestExpectation fulfill] for value exported."
    exportExpectation.assertForOverFulfill = false

    var mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: true))
    mockDataExporter.onExport = { _ in exportExpectation.fulfill() }

    // When
    let fileReader = FileReaderMock()
    fileReader.addFile(name: "file", data: "value".utf8Data)

    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { true },
                                  delay: mockDelay)

    // Then
    waitForExpectations(timeout: 1, handler: nil)
    worker.cancelSynchronously()
  }

  func testWhenBatchSucceeds_thenIntervalDecreases() {
    let delayChangeExpectation = expectation(description: "Export delay is decreased")
    let mockDelay = MockDelay { command in
      if case .decrease = command {
        delayChangeExpectation.fulfill()
      } else {
        XCTFail("Wrong command is sent!")
      }
    }

    let exportExpectation = expectation(description: "value exported")

    var mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: false))

    mockDataExporter.onExport = { _ in exportExpectation.fulfill() }

    // When
    let fileReader = FileReaderMock()
    fileReader.addFile(name: "file", data: "value".utf8Data)

    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { true },
                                  delay: mockDelay)

    // Then
    waitForExpectations(timeout: 1, handler: nil)
    worker.cancelSynchronously()
  }

  // MARK: - Tearing Down

  func testWhenCancelled_itPerformsNoMoreExports() {
    var mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: false))

    mockDataExporter.onExport = { _ in XCTFail("Expected no exports after cancel") }

    // When
    let fileReader = FileReaderMock()

    // Given
    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { false },
                                  delay: MockDelay())

    worker.cancelSynchronously()
    fileReader.addFile(name: "file", data: "value".utf8Data)

    // Then
    worker.queue.sync(flags: .barrier) {}
  }

  func testItFlushesAllData() {
    let v1ExportExpectation = expectation(description: "V1 exported")
    let v2ExportExpectation = expectation(description: "V2 exported")
    let v3ExportExpectation = expectation(description: "V3 exported")

    var mockDataExporter = DataExporterMock(exportStatus: .mockWith(needsRetry: false))

    mockDataExporter.onExport = { data in
      switch data.utf8String {
      case "v1": v1ExportExpectation.fulfill()
      case "v2": v2ExportExpectation.fulfill()
      case "v3": v3ExportExpectation.fulfill()
      default: break
      }
    }

    // Given
    let fileReader = FileReaderMock()
    fileReader.addFile(name: "1", data: "v1".utf8Data)
    fileReader.addFile(name: "2", data: "v2".utf8Data)
    fileReader.addFile(name: "3", data: "v3".utf8Data)

    // When
    let worker = DataExportWorker(fileReader: fileReader,
                                  dataExporter: mockDataExporter,
                                  exportCondition: { true },
                                  delay: DataExportDelay(performance: ExportPerformanceMock.veryQuick))

    // When
    XCTAssertTrue(worker.flush())

    // Then
    waitForExpectations(timeout: 1, handler: nil)
    XCTAssertEqual(fileReader.files.count, 0)
  }
}

struct MockDelay: Delay {
  enum Command {
    case increase, decrease
  }

  var callback: ((Command) -> Void)?
  let current: TimeInterval = 0.1

  mutating func decrease() {
    callback?(.decrease)
    callback = nil
  }

  mutating func increase() {
    callback?(.increase)
    callback = nil
  }
}

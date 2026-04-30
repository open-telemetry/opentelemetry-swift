/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import XCTest

class PersistenceExporterDecoratorTests: XCTestCase {
  class DecoratedExporterMock<T>: DecoratedExporter {
    typealias SignalType = T
    let exporter: ([T]) -> DataExportStatus
    init(exporter: @escaping ([T]) -> DataExportStatus) {
      self.exporter = exporter
    }

    func export(values: [T]) -> DataExportStatus {
      return exporter(values)
    }
  }

  class DataExportWorkerMock: DataExportWorkerProtocol {
    var dataExporter: DataExporter? = nil
    var onFlush: (() -> Bool)? = nil

    func flush() -> Bool {
      return onFlush?() ?? true
    }
  }

  private typealias PersistenceExporter<T: Codable> = PersistenceExporterDecorator<DecoratedExporterMock<T>>

  private func createPersistenceExporter<T: Codable>(fileWriter: FileWriterMock = FileWriterMock(),
                                                     worker: inout DataExportWorkerMock,
                                                     decoratedExporter: DecoratedExporterMock<T> = DecoratedExporterMock(exporter: { _ in
                                                       return DataExportStatus(needsRetry: false)
                                                     }),
                                                     storagePerformance: StoragePerformancePreset = StoragePerformanceMock.writeEachObjectToNewFileAndReadAllFiles,
                                                     synchronousWrite: Bool = true,
                                                     exportPerformance: ExportPerformancePreset = ExportPerformanceMock.veryQuick) -> PersistenceExporter<T> {
    return PersistenceExporterDecorator<DecoratedExporterMock<T>>(decoratedExporter: decoratedExporter,
                                                                  fileWriter: fileWriter,
                                                                  workerFactory: {
                                                                    worker.dataExporter = $0
                                                                    return worker
                                                                  },
                                                                  performancePreset: PersistencePerformancePreset.mockWith(storagePerformance: storagePerformance,
                                                                                                                           synchronousWrite: synchronousWrite,
                                                                                                                           exportPerformance: exportPerformance))
  }

  func testWhenSetupWithSynchronousWrite_thenWritesAreSynchronous() throws {
    var worker = DataExportWorkerMock()
    let fileWriter = FileWriterMock()

    let exporter: PersistenceExporter<String> = createPersistenceExporter(fileWriter: fileWriter,
                                                                          worker: &worker)

    fileWriter.onWrite = { writeSync, _ in
      XCTAssertTrue(writeSync)
    }

    try exporter.export(values: ["value"])
  }

  func testWhenSetupWithAsynchronousWrite_thenWritesAreAsynchronous() throws {
    var worker = DataExportWorkerMock()
    let fileWriter = FileWriterMock()

    let exporter: PersistenceExporter<String> = createPersistenceExporter(fileWriter: fileWriter,
                                                                          worker: &worker,
                                                                          synchronousWrite: false)

    fileWriter.onWrite = { writeSync, _ in
      XCTAssertFalse(writeSync)
    }

    try exporter.export(values: ["value"])
  }

  func testWhenValueCannotBeEncoded_itThrowsAnError() {
    // When
    var worker = DataExportWorkerMock()

    let exporter: PersistenceExporter<FailingCodableMock> = createPersistenceExporter(
      worker: &worker)

    XCTAssertThrowsError(try exporter.export(values: [FailingCodableMock()]))
  }

  func testWhenValueCannotBeDecoded_itReportsNoRetryIsNeeded() {
    var worker = DataExportWorkerMock()

    _ = createPersistenceExporter(worker: &worker) as PersistenceExporter<FailingCodableMock>

    let result = worker.dataExporter?.export(data: Data())

    XCTAssertNotNil(result)
    XCTAssertFalse(result!.needsRetry)
  }

  func testWhenItIsFlushed_thenItFlushesTheWriterAndWorker() {
    let writerIsFlushedExpectation = expectation(description: "FileWriter was flushed")
    let workerIsFlushedExpectation = expectation(description: "DataExportWorker was flushed")

    var worker = DataExportWorkerMock()
    let fileWriter = FileWriterMock()

    let exporter: PersistenceExporter<String> = createPersistenceExporter(fileWriter: fileWriter,
                                                                          worker: &worker)

    fileWriter.onFlush = {
      writerIsFlushedExpectation.fulfill()
    }

    worker.onFlush = {
      workerIsFlushedExpectation.fulfill()
      return true
    }

    exporter.flush()

    waitForExpectations(timeout: 1, handler: nil)
  }

  func testWhenObjectsDataIsExportedSeparately_thenObjectsAreExported() throws {
    let v1ExportExpectation = expectation(description: "V1 exported")
    let v2ExportExpectation = expectation(description: "V2 exported")
    let v3ExportExpectation = expectation(description: "V3 exported")

    let decoratedExporter = DecoratedExporterMock<String>(exporter: { values in
      values.forEach { value in
        switch value {
        case "v1": v1ExportExpectation.fulfill()
        case "v2": v2ExportExpectation.fulfill()
        case "v3": v3ExportExpectation.fulfill()
        default: break
        }
      }

      return DataExportStatus(needsRetry: false)
    })

    var worker = DataExportWorkerMock()
    let fileWriter = FileWriterMock()

    let exporter: PersistenceExporter<String> = createPersistenceExporter(fileWriter: fileWriter,
                                                                          worker: &worker,
                                                                          decoratedExporter: decoratedExporter)

    fileWriter.onWrite = { _, data in
      if let dataExporter = worker.dataExporter {
        XCTAssertFalse(dataExporter.export(data: data).needsRetry)
      }
    }

    try exporter.export(values: ["v1"])
    try exporter.export(values: ["v2"])
    try exporter.export(values: ["v3"])

    waitForExpectations(timeout: 1, handler: nil)
  }

  func testWhenObjectsDataIsExportedConcatenated_thenObjectsAreExported() throws {
    let v1ExportExpectation = expectation(description: "V1 exported")
    let v2ExportExpectation = expectation(description: "V2 exported")
    let v3ExportExpectation = expectation(description: "V3 exported")

    let decoratedExporter = DecoratedExporterMock<String>(exporter: { values in
      values.forEach { value in
        switch value {
        case "v1": v1ExportExpectation.fulfill()
        case "v2": v2ExportExpectation.fulfill()
        case "v3": v3ExportExpectation.fulfill()
        default: break
        }
      }

      return DataExportStatus(needsRetry: false)
    })

    var worker = DataExportWorkerMock()
    let fileWriter = FileWriterMock()

    let exporter: PersistenceExporter<String> = createPersistenceExporter(fileWriter: fileWriter,
                                                                          worker: &worker,
                                                                          decoratedExporter: decoratedExporter)

    var writtenData = Data()
    fileWriter.onWrite = { _, data in
      writtenData.append(data)
    }

    try exporter.export(values: ["v1"])
    try exporter.export(values: ["v2"])
    try exporter.export(values: ["v3"])

    if let dataExporter = worker.dataExporter {
      XCTAssertFalse(dataExporter.export(data: writtenData).needsRetry)
    }

    waitForExpectations(timeout: 1, handler: nil)
  }
}

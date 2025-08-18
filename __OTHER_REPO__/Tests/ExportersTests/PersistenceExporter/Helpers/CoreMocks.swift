/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import Foundation

// MARK: - PerformancePreset Mocks

struct StoragePerformanceMock: StoragePerformancePreset {
  let maxFileSize: UInt64
  let maxDirectorySize: UInt64
  let maxFileAgeForWrite: TimeInterval
  let minFileAgeForRead: TimeInterval
  let maxFileAgeForRead: TimeInterval
  let maxObjectsInFile: Int
  let maxObjectSize: UInt64

  static let readAllFiles = StoragePerformanceMock(maxFileSize: .max,
                                                   maxDirectorySize: .max,
                                                   maxFileAgeForWrite: 0,
                                                   minFileAgeForRead: -1, // make all files eligible for read
                                                   maxFileAgeForRead: .distantFuture, // make all files eligible for read
                                                   maxObjectsInFile: .max,
                                                   maxObjectSize: .max)

  static let writeEachObjectToNewFileAndReadAllFiles = StoragePerformanceMock(maxFileSize: .max,
                                                                              maxDirectorySize: .max,
                                                                              maxFileAgeForWrite: 0, // always return new file for writing
                                                                              minFileAgeForRead: readAllFiles.minFileAgeForRead,
                                                                              maxFileAgeForRead: readAllFiles.maxFileAgeForRead,
                                                                              maxObjectsInFile: 1, // write each data to new file
                                                                              maxObjectSize: .max)

  static let writeAllObjectsToTheSameFile = StoragePerformanceMock(maxFileSize: .max,
                                                                   maxDirectorySize: .max,
                                                                   maxFileAgeForWrite: .distantFuture,
                                                                   minFileAgeForRead: -1, // make all files eligible for read
                                                                   maxFileAgeForRead: .distantFuture, // make all files eligible for read
                                                                   maxObjectsInFile: .max,
                                                                   maxObjectSize: .max)
}

struct ExportPerformanceMock: ExportPerformancePreset {
  let initialExportDelay: TimeInterval
  let defaultExportDelay: TimeInterval
  let minExportDelay: TimeInterval
  let maxExportDelay: TimeInterval
  let exportDelayChangeRate: Double

  static let veryQuick = ExportPerformanceMock(initialExportDelay: 0.05,
                                               defaultExportDelay: 0.05,
                                               minExportDelay: 0.05,
                                               maxExportDelay: 0.05,
                                               exportDelayChangeRate: 0)
}

extension PersistencePerformancePreset {
  static func mockWith(storagePerformance: StoragePerformancePreset,
                       synchronousWrite: Bool,
                       exportPerformance: ExportPerformancePreset) -> PersistencePerformancePreset {
    return PersistencePerformancePreset(maxFileSize: storagePerformance.maxFileSize,
                                        maxDirectorySize: storagePerformance.maxDirectorySize,
                                        maxFileAgeForWrite: storagePerformance.maxFileAgeForWrite,
                                        minFileAgeForRead: storagePerformance.minFileAgeForRead,
                                        maxFileAgeForRead: storagePerformance.maxFileAgeForRead,
                                        maxObjectsInFile: storagePerformance.maxObjectsInFile,
                                        maxObjectSize: storagePerformance.maxObjectSize,
                                        synchronousWrite: synchronousWrite,
                                        initialExportDelay: exportPerformance.initialExportDelay,
                                        defaultExportDelay: exportPerformance.defaultExportDelay,
                                        minExportDelay: exportPerformance.minExportDelay,
                                        maxExportDelay: exportPerformance.maxExportDelay,
                                        exportDelayChangeRate: exportPerformance.exportDelayChangeRate)
  }
}

/// `DateProvider` mock returning consecutive dates in custom intervals, starting from given reference date.
class RelativeDateProvider: DateProvider {
  private(set) var date: Date
  let timeInterval: TimeInterval
  private let queue = DispatchQueue(label: "queue-RelativeDateProvider-\(UUID().uuidString)")

  private init(date: Date, timeInterval: TimeInterval) {
    self.date = date
    self.timeInterval = timeInterval
  }

  convenience init(using date: Date = Date()) {
    self.init(date: date, timeInterval: 0)
  }

  convenience init(startingFrom referenceDate: Date = Date(), advancingBySeconds timeInterval: TimeInterval = 0) {
    self.init(date: referenceDate, timeInterval: timeInterval)
  }

  /// Returns current date and advances next date by `timeInterval`.
  func currentDate() -> Date {
    defer {
      queue.async {
        self.date.addTimeInterval(self.timeInterval)
      }
    }
    return queue.sync {
      return date
    }
  }

  /// Pushes time forward by given number of seconds.
  func advance(bySeconds seconds: TimeInterval) {
    queue.async {
      self.date = self.date.addingTimeInterval(seconds)
    }
  }
}

struct DataExporterMock: DataExporter {
  let exportStatus: DataExportStatus

  var onExport: ((Data) -> Void)? = nil

  func export(data: Data) -> DataExportStatus {
    onExport?(data)
    return exportStatus
  }
}

extension DataExportStatus {
  static func mockWith(needsRetry: Bool) -> DataExportStatus {
    return DataExportStatus(needsRetry: needsRetry)
  }
}

class FileWriterMock: FileWriter {
  var onWrite: ((Bool, Data) -> Void)? = nil

  func write(data: Data) {
    onWrite?(false, data)
  }

  func writeSync(data: Data) {
    onWrite?(true, data)
  }

  var onFlush: (() -> Void)? = nil

  func flush() {
    onFlush?()
  }
}

class FileReaderMock: FileReader {
  private class ReadableFileMock: ReadableFile {
    private var deleted = false
    private let data: Data

    private(set) var name: String

    init(name: String, data: Data) {
      self.name = name
      self.data = data
    }

    func read() throws -> Data {
      guard deleted == false else {
        throw ErrorMock("read failed because delete was called")
      }
      return data
    }

    func delete() throws {
      deleted = true
    }
  }

  var files: [ReadableFile] = []

  func addFile(name: String, data: Data) {
    files.append(ReadableFileMock(name: name, data: data))
  }

  func readNextBatch() -> Batch? {
    if let file = files.first,
       let fileData = try? file.read() {
      return Batch(data: fileData, file: file)
    }

    return nil
  }

  func onRemainingBatches(process: (Batch) -> Void) -> Bool {
    do {
      try files.forEach {
        let fileData = try $0.read()
        process(Batch(data: fileData, file: $0))
      }

      return true
    } catch {
      return false
    }
  }

  func markBatchAsRead(_ batch: Batch) {
    try? batch.file.delete()
    files.removeAll { file -> Bool in
      return file.name == batch.file.name
    }
  }
}

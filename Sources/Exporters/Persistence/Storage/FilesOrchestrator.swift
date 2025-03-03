/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class FilesOrchestrator {
  /// Directory where files are stored.
  private let directory: Directory
  /// Date provider.
  private let dateProvider: DateProvider
  /// Performance rules for writing and reading files.
  private let performance: StoragePerformancePreset
  /// Name of the last file returned by `getWritableFile()`.
  private var lastWritableFileName: String?
  /// Tracks number of times the file at `lastWritableFileURL` was returned from `getWritableFile()`.
  /// This should correspond with number of objects stored in file, assuming that majority of writes succeed (the difference is negligible).
  private var lastWritableFileUsesCount: Int = 0

  init(directory: Directory,
       performance: StoragePerformancePreset,
       dateProvider: DateProvider) {
    self.directory = directory
    self.performance = performance
    self.dateProvider = dateProvider
  }

  // MARK: - `WritableFile` orchestration

  func getWritableFile(writeSize: UInt64) throws -> WritableFile {
    if writeSize > performance.maxObjectSize {
      throw StorageError.dataExceedsMaxSizeError(dataSize: writeSize, maxSize: performance.maxObjectSize)
    }

    let lastWritableFileOrNil = reuseLastWritableFileIfPossible(writeSize: writeSize)

    if let lastWritableFile = lastWritableFileOrNil { // if last writable file can be reused
      lastWritableFileUsesCount += 1
      return lastWritableFile
    } else {
      // NOTE: As purging files directory is a memory-expensive operation, do it only when we know
      // that a new file will be created. With SDK's `PerformancePreset` this gives
      // the process enough time to not over-allocate internal `_FileCache` and `_NSFastEnumerationEnumerator`
      // objects, resulting with a flat allocations graph in a long term.
      try purgeFilesDirectoryIfNeeded()

      let newFileName = fileNameFrom(fileCreationDate: dateProvider.currentDate())
      let newFile = try directory.createFile(named: newFileName)
      lastWritableFileName = newFile.name
      lastWritableFileUsesCount = 1
      return newFile
    }
  }

  private func reuseLastWritableFileIfPossible(writeSize: UInt64) -> WritableFile? {
    if let lastFileName = lastWritableFileName {
      do {
        guard let lastFile = directory.file(named: lastFileName) else {
          return nil
        }
        let lastFileCreationDate = fileCreationDateFrom(fileName: lastFile.name)
        let lastFileAge = dateProvider.currentDate().timeIntervalSince(lastFileCreationDate)

        let fileIsRecentEnough = lastFileAge <= performance.maxFileAgeForWrite
        let fileHasRoomForMore = try (lastFile.size() + writeSize) <= performance.maxFileSize
        let fileCanBeUsedMoreTimes = (lastWritableFileUsesCount + 1) <= performance.maxObjectsInFile

        if fileIsRecentEnough, fileHasRoomForMore, fileCanBeUsedMoreTimes {
          return lastFile
        }
      } catch {
        return nil
      }
    }

    return nil
  }

  // MARK: - `ReadableFile` orchestration

  func getReadableFile(excludingFilesNamed excludedFileNames: Set<String> = []) -> ReadableFile? {
    do {
      let filesWithCreationDate = try directory.files()
        .map { (file: $0, creationDate: fileCreationDateFrom(fileName: $0.name)) }
        .compactMap { try deleteFileIfItsObsolete(file: $0.file, fileCreationDate: $0.creationDate) }

      guard let (oldestFile, creationDate) = filesWithCreationDate
        .filter({ excludedFileNames.contains($0.file.name) == false })
        .sorted(by: { $0.creationDate < $1.creationDate })
        .first
      else {
        return nil
      }

      let oldestFileAge = dateProvider.currentDate().timeIntervalSince(creationDate)
      let fileIsOldEnough = oldestFileAge >= performance.minFileAgeForRead

      return fileIsOldEnough ? oldestFile : nil
    } catch {
      return nil
    }
  }

  func getAllFiles(excludingFilesNamed excludedFileNames: Set<String> = []) -> [ReadableFile]? {
    do {
      return try directory.files()
        .filter { excludedFileNames.contains($0.name) == false }
    } catch {
      return nil
    }
  }

  func delete(readableFile: ReadableFile) {
    do {
      try readableFile.delete()
    } catch {}
  }

  // MARK: - Directory size management

  /// Removes oldest files from the directory if it becomes too big.
  private func purgeFilesDirectoryIfNeeded() throws {
    let filesSortedByCreationDate = try directory.files()
      .map { (file: $0, creationDate: fileCreationDateFrom(fileName: $0.name)) }
      .sorted { $0.creationDate < $1.creationDate }

    var filesWithSizeSortedByCreationDate = try filesSortedByCreationDate
      .map { try (file: $0.file, size: $0.file.size()) }

    let accumulatedFilesSize = filesWithSizeSortedByCreationDate.map(\.size).reduce(0, +)

    if accumulatedFilesSize > performance.maxDirectorySize {
      let sizeToFree = accumulatedFilesSize - performance.maxDirectorySize
      var sizeFreed: UInt64 = 0

      while sizeFreed < sizeToFree, !filesWithSizeSortedByCreationDate.isEmpty {
        let fileWithSize = filesWithSizeSortedByCreationDate.removeFirst()
        try fileWithSize.file.delete()
        sizeFreed += fileWithSize.size
      }
    }
  }

  private func deleteFileIfItsObsolete(file: File, fileCreationDate: Date) throws -> (file: File, creationDate: Date)? {
    let fileAge = dateProvider.currentDate().timeIntervalSince(fileCreationDate)

    if fileAge > performance.maxFileAgeForRead {
      try file.delete()
      return nil
    } else {
      return (file: file, creationDate: fileCreationDate)
    }
  }
}

/// File creation date is used as file name - timestamp in milliseconds is used for date representation.
/// This function converts file creation date into file name.
func fileNameFrom(fileCreationDate: Date) -> String {
  let milliseconds = fileCreationDate.timeIntervalSinceReferenceDate * 1_000
  let converted = (try? UInt64(withReportingOverflow: milliseconds)) ?? 0
  return String(converted)
}

/// File creation date is used as file name - timestamp in milliseconds is used for date representation.
/// This function converts file name into file creation date.
func fileCreationDateFrom(fileName: String) -> Date {
  let millisecondsSinceReferenceDate = TimeInterval(UInt64(fileName) ?? 0) / 1_000
  return Date(timeIntervalSinceReferenceDate: TimeInterval(millisecondsSinceReferenceDate))
}

private enum FixedWidthIntegerError<T: BinaryFloatingPoint>: Error {
  case overflow(overflowingValue: T)
}

private extension FixedWidthInteger {
  /*
   Self(:) is commonly used for conversion, however it fatalError() in case of conversion failure
   Self(exactly:) does the exact same thing internally yet it returns nil instead of fatalError()
   It is not trivial to guess if the conversion would fail or succeed, therefore we use Self(exactly:)
   so that we don't need to guess in order to save the app from crashing

   IMPORTANT: If you pass floatingPoint to Self(exactly:) without rounded(), it may return nil
   */
  init<T: BinaryFloatingPoint>(withReportingOverflow floatingPoint: T) throws {
    guard let converted = Self(exactly: floatingPoint.rounded()) else {
      throw FixedWidthIntegerError<T>.overflow(overflowingValue: floatingPoint)
    }
    self = converted
  }
}

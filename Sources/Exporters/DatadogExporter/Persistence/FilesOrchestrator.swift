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

internal class FilesOrchestrator {
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

    init(
        directory: Directory,
        performance: StoragePerformancePreset,
        dateProvider: DateProvider
    ) {
        self.directory = directory
        self.performance = performance
        self.dateProvider = dateProvider
    }

    // MARK: - `WritableFile` orchestration

    func getWritableFile(writeSize: UInt64) throws -> WritableFile {
        if writeSize > performance.maxObjectSize {
            throw ExporterError(description: "data exceeds the maximum size of \(performance.maxObjectSize) bytes.")
        }

        let lastWritableFileOrNil = reuseLastWritableFileIfPossible(writeSize: writeSize)

        if let lastWritableFile = lastWritableFileOrNil { // if last writable file can be reused
            lastWritableFileUsesCount += 1
            return lastWritableFile
        } else {
            // NOTE: RUMM-610 As purging files directory is a memory-expensive operation, do it only when we know
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
                let fileHasRoomForMore = (try lastFile.size() + writeSize) <= performance.maxFileSize
                let fileCanBeUsedMoreTimes = (lastWritableFileUsesCount + 1) <= performance.maxObjectsInFile

                if fileIsRecentEnough, fileHasRoomForMore, fileCanBeUsedMoreTimes {
                    return lastFile
                }
            } catch {
                print("🔥 Failed to read previously used writable file: \(error)")
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
            print("🔥 Failed to obtain readable file: \(error)")
            return nil
        }
    }

    func getAllFiles(excludingFilesNamed excludedFileNames: Set<String> = []) -> [ReadableFile]? {
        do {
            return try directory.files()
                .filter({ excludedFileNames.contains($0.name) == false })
        } catch {
            print("🔥 Failed to obtain readable files: \(error)")
            return nil
        }
    }

    func delete(readableFile: ReadableFile) {
        do {
            try readableFile.delete()
        } catch {
            print("🔥 Failed to delete file: \(error)")
        }
    }

    // MARK: - Directory size management

    /// Removes oldest files from the directory if it becomes too big.
    private func purgeFilesDirectoryIfNeeded() throws {
        let filesSortedByCreationDate = try directory.files()
            .map { (file: $0, creationDate: fileCreationDateFrom(fileName: $0.name)) }
            .sorted { $0.creationDate < $1.creationDate }

        var filesWithSizeSortedByCreationDate = try filesSortedByCreationDate
            .map { (file: $0.file, size: try $0.file.size()) }

        let accumulatedFilesSize = filesWithSizeSortedByCreationDate.map { $0.size }.reduce(0, +)

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
internal func fileNameFrom(fileCreationDate: Date) -> String {
    let milliseconds = fileCreationDate.timeIntervalSinceReferenceDate * 1_000
    let converted = (try? UInt64(withReportingOverflow: milliseconds)) ?? 0
    return String(converted)
}

/// File creation date is used as file name - timestamp in milliseconds is used for date representation.
/// This function converts file name into file creation date.
internal func fileCreationDateFrom(fileName: String) -> Date {
    let millisecondsSinceReferenceDate = TimeInterval(UInt64(fileName) ?? 0) / 1_000
    return Date(timeIntervalSinceReferenceDate: TimeInterval(millisecondsSinceReferenceDate))
}

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

/// An abstraction over file system directory where SDK stores its files.
internal struct Directory {
    let url: URL

    /// Creates subdirectory with given path under system caches directory.
    init(withSubdirectoryPath path: String) throws {
        self.init(url: try createCachesSubdirectoryIfNotExists(subdirectoryPath: path))
    }

    init(url: URL) {
        self.url = url
    }

    /// Creates file with given name.
    func createFile(named fileName: String) throws -> File {
        let fileURL = url.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil) == true else {
            throw ExporterError(description: "Cannot create file at path: \(fileURL.path)")
        }
        return File(url: fileURL)
    }

    /// Returns file with given name.
    func file(named fileName: String) -> File? {
        let fileURL = url.appendingPathComponent(fileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return File(url: fileURL)
        } else {
            return nil
        }
    }

    /// Returns all files of this directory.
    func files() throws -> [File] {
        return try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey, .canonicalPathKey])
            .map { url in File(url: url) }
    }
}

/// Creates subdirectory at given path in `/Library/Caches` if it does not exist. Might throw `ExporterError` when it's not possible.
/// * `/Library/Caches` is exclduded from iTunes and iCloud backups by default.
/// * System may delete data in `/Library/Cache` to free up disk space which reduces the impact on devices working under heavy space pressure.
private func createCachesSubdirectoryIfNotExists(subdirectoryPath: String) throws -> URL {
    guard let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        throw ExporterError(description: "Cannot obtain `/Library/Caches/` url.")
    }
    let subdirectoryURL = cachesDirectoryURL.appendingPathComponent(subdirectoryPath, isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        throw ExporterError(description: "Cannot create subdirectory in `/Library/Caches/` folder.")
    }
    return subdirectoryURL
}

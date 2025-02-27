/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An abstraction over file system directory where SDK stores its files.
struct Directory {
  let url: URL

  /// Creates subdirectory with given path under system caches directory.
  init(withSubdirectoryPath path: String) throws {
    try self.init(url: createCachesSubdirectoryIfNotExists(subdirectoryPath: path))
  }

  init(url: URL) {
    self.url = url
  }

  /// Creates file with given name.
  func createFile(named fileName: String) throws -> File {
    let fileURL = url.appendingPathComponent(fileName, isDirectory: false)
    guard FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil) == true else {
      throw StorageError.createFileError(path: fileURL)
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

/// Creates subdirectory at given path in `/Library/Caches` if it does not exist. Might throw `PersistenceError` when it's not possible.
/// * `/Library/Caches` is exclduded from iTunes and iCloud backups by default.
/// * System may delete data in `/Library/Cache` to free up disk space which reduces the impact on devices working under heavy space pressure.
private func createCachesSubdirectoryIfNotExists(subdirectoryPath: String) throws -> URL {
  guard let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
    throw StorageError.obtainCacheLibraryError
  }

  let subdirectoryURL = cachesDirectoryURL.appendingPathComponent(subdirectoryPath, isDirectory: true)

  do {
    try FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true, attributes: nil)
  } catch {
    throw StorageError.createDirectoryError(path: subdirectoryURL, error: error)
  }

  return subdirectoryURL
}

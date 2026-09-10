/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIOConcurrencyHelpers

final class JSONLinesSink: @unchecked Sendable {
  private let directory: URL
  private let lock = NIOLock()

  init(directory: URL) throws {
    self.directory = directory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  func append(line: Data, to fileName: String) throws {
    try lock.withLockVoid {
      let url = directory.appendingPathComponent(fileName)
      if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
      }
      let handle = try FileHandle(forWritingTo: url)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: line)
      try handle.write(contentsOf: Data("\n".utf8))
    }
  }
}

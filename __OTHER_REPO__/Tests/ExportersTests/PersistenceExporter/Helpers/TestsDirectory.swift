/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import Foundation
import XCTest

/// Creates `Directory` pointing to unique subfolder in `/var/folders/`.
/// Does not create the subfolder - it must be later created with `.create()`.
@propertyWrapper class UniqueTemporaryDirectory {
  private let directory: Directory
  private var printedDir = false

  var wrappedValue: Directory {
    if printedDir == false {
      printedDir = true
      // Printing this message during initialization breaks `swift test --filter...` on platforms without Objective-C support, so we do it on first access instead
      print("💡 Obtained temporary directory URL: \(directory.url)")
    }

    return directory
  }

  init() {
    let subdirectoryName = "com.datadoghq.ios-sdk-tests-\(UUID().uuidString)"
    let osTemporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(subdirectoryName, isDirectory: true)
    directory = Directory(url: osTemporaryDirectoryURL)
  }
}

/// `Directory` pointing to subfolder in `/var/folders/`.
/// The subfolder does not exist and can be created and deleted by calling `.create()` and `.delete()`.
// let temporaryDirectory = obtainUniqueTemporaryDirectory()

/// Extends `Directory` with set of utilities for convenient work with files in tests.
/// Provides handy methods to create / delete files and directires.
extension Directory {
  /// Creates empty directory with given attributes .
  func create(attributes: [FileAttributeKey: Any]? = nil, file: StaticString = #file, line: UInt = #line) {
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: attributes)
      let initialFilesCount = try files().count
      XCTAssert(initialFilesCount == 0, "🔥 `TestsDirectory` is not empty: \(url)", file: file, line: line)
    } catch {
      XCTFail("🔥 Failed to create `TestsDirectory`: \(error)", file: file, line: line)
    }
  }

  /// Deletes entire directory with its content.
  func delete(file: StaticString = #file, line: UInt = #line) {
    if FileManager.default.fileExists(atPath: url.path) {
      do {
        try FileManager.default.removeItem(at: url)
      } catch {
        XCTFail("🔥 Failed to delete `TestsDirectory`: \(error)", file: file, line: line)
      }
    }
  }
}

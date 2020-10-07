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

@testable import DatadogExporter
import Foundation
import XCTest

/// Creates `Directory` pointing to unique subfolder in `/var/folders/`.
/// Does not create the subfolder - it must be later created with `.create()`.
func obtainUniqueTemporaryDirectory() -> Directory {
    let subdirectoryName = "com.datadoghq.ios-sdk-tests-\(UUID().uuidString)"
    let osTemporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(subdirectoryName, isDirectory: true)
    print("💡 Obtained temporary directory URL: \(osTemporaryDirectoryURL)")
    return Directory(url: osTemporaryDirectoryURL)
}

/// `Directory` pointing to subfolder in `/var/folders/`.
/// The subfolder does not exist and can be created and deleted by calling `.create()` and `.delete()`.
let temporaryDirectory = obtainUniqueTemporaryDirectory()

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

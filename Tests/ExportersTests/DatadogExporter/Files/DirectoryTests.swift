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
import XCTest

class DirectoryTests: XCTestCase {
    private let uniqueSubdirectoryName = UUID().uuidString
    private let fileManager = FileManager.default

    // MARK: - Directory creation

    func testGivenSubdirectoryName_itCreatesIt() throws {
        let directory = try Directory(withSubdirectoryPath: uniqueSubdirectoryName)
        defer { directory.delete() }

        XCTAssertTrue(fileManager.fileExists(atPath: directory.url.path))
    }

    func testGivenSubdirectoryPath_itCreatesIt() throws {
        let path = uniqueSubdirectoryName + "/subdirectory/another-subdirectory"
        let directory = try Directory(withSubdirectoryPath: path)
        defer { directory.delete() }

        XCTAssertTrue(fileManager.fileExists(atPath: directory.url.path))
    }

    func testWhenDirectoryExists_itDoesNothing() throws {
        let path = uniqueSubdirectoryName + "/subdirectory/another-subdirectory"
        let originalDirectory = try Directory(withSubdirectoryPath: path)
        defer { originalDirectory.delete() }
        _ = try originalDirectory.createFile(named: "abcd")

        // Try again when directory exists
        let retrievedDirectory = try Directory(withSubdirectoryPath: path)

        XCTAssertEqual(retrievedDirectory.url, originalDirectory.url)
        XCTAssertTrue(fileManager.fileExists(atPath: retrievedDirectory.url.appendingPathComponent("abcd").path))
    }

    // MARK: - Files manipulation

    func testItCreatesFile() throws {
        let path = uniqueSubdirectoryName + "/subdirectory/another-subdirectory"
        let directory = try Directory(withSubdirectoryPath: path)
        defer { directory.delete() }

        let file = try directory.createFile(named: "abcd")

        XCTAssertEqual(file.url, directory.url.appendingPathComponent("abcd"))
        XCTAssertTrue(fileManager.fileExists(atPath: file.url.path))
    }

    func testItRetrievesFile() throws {
        let directory = try Directory(withSubdirectoryPath: uniqueSubdirectoryName)
        defer { directory.delete() }
        _ = try directory.createFile(named: "abcd")

        let file = directory.file(named: "abcd")
        XCTAssertEqual(file?.url, directory.url.appendingPathComponent("abcd"))
        XCTAssertTrue(fileManager.fileExists(atPath: file!.url.path))
    }

    func testItRetrievesAllFiles() throws {
        let directory = try Directory(withSubdirectoryPath: uniqueSubdirectoryName)
        defer { directory.delete() }
        _ = try directory.createFile(named: "f1")
        _ = try directory.createFile(named: "f2")
        _ = try directory.createFile(named: "f3")

        let files = try directory.files()
        XCTAssertEqual(files.count, 3)
        files.forEach { file in XCTAssertTrue(file.url.relativePath.contains(directory.url.relativePath)) }
        files.forEach { file in XCTAssertTrue(fileManager.fileExists(atPath: file.url.path)) }
    }
}

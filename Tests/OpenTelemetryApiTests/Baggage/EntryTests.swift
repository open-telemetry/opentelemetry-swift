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

import OpenTelemetryApi
import XCTest

class EntryTests: XCTestCase {
    let key = EntryKey(name: "KEY")!
    let key2 = EntryKey(name: "KEY2")!
    let value = EntryValue(string: "VALUE")!
    let value2 = EntryValue(string: "VALUE2")!
    let metadata1 = EntryMetadata(metadata: "test1")
    let metadata2 = EntryMetadata(metadata: "test2")

    func testGetKey() {
        XCTAssertEqual(Entry(key: key, value: value, metadata: metadata1).key, key)
    }

    func testGetEntryMetadata() {
        XCTAssertEqual(Entry(key: key, value: value, metadata: metadata2).metadata, metadata2)
    }

    func testEntryEquals() {
        XCTAssertEqual(Entry(key: key, value: value, metadata: metadata1), Entry(key: key, value: value, metadata: metadata1))
        XCTAssertNotEqual(Entry(key: key, value: value, metadata: metadata1), Entry(key: key, value: value2, metadata: metadata1))
        XCTAssertNotEqual(Entry(key: key, value: value, metadata: metadata1), Entry(key: key2, value: value, metadata: metadata1))
        XCTAssertNotEqual(Entry(key: key, value: value, metadata: metadata1), Entry(key: key, value: value, metadata: metadata2))
        XCTAssertEqual(Entry(key: key, value: value2, metadata: metadata1), Entry(key: key, value: value2, metadata: metadata1))
        XCTAssertNotEqual(Entry(key: key, value: value2, metadata: metadata1), Entry(key: key2, value: value, metadata: metadata1))
        XCTAssertNotEqual(Entry(key: key, value: value2, metadata: metadata1), Entry(key: key, value: value, metadata: metadata2))
        XCTAssertEqual(Entry(key: key2, value: value, metadata: metadata1), Entry(key: key2, value: value, metadata: metadata1))
        XCTAssertNotEqual(Entry(key: key2, value: value, metadata: metadata1), Entry(key: key, value: value, metadata: metadata2))
        XCTAssertEqual(Entry(key: key, value: value, metadata: metadata2), Entry(key: key, value: value, metadata: metadata2))
    }
}

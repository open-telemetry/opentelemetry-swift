/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

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

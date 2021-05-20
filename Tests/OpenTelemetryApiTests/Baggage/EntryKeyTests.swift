/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class EntryKeyTests: XCTestCase {
    func testMaxLength() {
        XCTAssertEqual(EntryKey.maxLength, 255)
    }

    func testGetName() {
        XCTAssertEqual(EntryKey(name: "foo")?.name, "foo")
    }

    func testCreate_AllowEntryKeyNameWithMaxLength() {
        let key = String(repeating: "k", count: EntryKey.maxLength)
        XCTAssertEqual(EntryKey(name: key)?.name, key)
    }

    func testCreate_DisallowEntryKeyNameOverMaxLength() {
        let key = String(repeating: "k", count: EntryKey.maxLength + 1)
        XCTAssertNil(EntryKey(name: key)?.name)
    }

    func testCreate_DisallowUnprintableChars() {
        let key = String("\0")
        XCTAssertNil(EntryKey(name: key)?.name)
    }

    func testCreateString_DisallowEmpty() {
        let key = String("")
        XCTAssertNil(EntryKey(name: key)?.name)
    }

    func testEntryKeyEquals() {
        XCTAssertEqual(EntryKey(name: "foo"), EntryKey(name: "foo"))
        XCTAssertNotEqual(EntryKey(name: "foo"), EntryKey(name: "bar"))
    }
}

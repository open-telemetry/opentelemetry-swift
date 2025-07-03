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

  func testBasicKeyBehavior() {
    // Basic creation and equality
    let key1 = EntryKey(name: "foo")
    let key2 = EntryKey(name: "foo")
    let key3 = EntryKey(name: "bar")

    XCTAssertEqual(key1?.name, "foo")
    XCTAssertEqual(key1, key2)
    XCTAssertNotEqual(key1, key3)
  }

  func testLengthValidation() {
    // Test maximum length
    let maxKey = String(repeating: "k", count: EntryKey.maxLength)
    XCTAssertNotNil(EntryKey(name: maxKey))

    // Test over maximum length
    let overMaxKey = String(repeating: "k", count: EntryKey.maxLength + 1)
    XCTAssertNil(EntryKey(name: overMaxKey))

    // Test empty
    XCTAssertNil(EntryKey(name: ""))
  }

  func testRFC7230TokenValidation() {
    // Valid tokens according to RFC7230
    XCTAssertNotNil(EntryKey(name: "simple-key"))
    XCTAssertNotNil(EntryKey(name: "key_with_underscore"))
    XCTAssertNotNil(EntryKey(name: "key.with.dots"))
    XCTAssertNotNil(EntryKey(name: "!#$%&'*+-.^_`|~")) // all special chars
    XCTAssertNotNil(EntryKey(name: "123numeric456"))

    // Invalid tokens
    XCTAssertNil(EntryKey(name: "key with spaces"))
    XCTAssertNil(EntryKey(name: "key\twith\ttabs"))
    XCTAssertNil(EntryKey(name: "key:with:colons"))
    XCTAssertNil(EntryKey(name: "key/with/slashes"))
    XCTAssertNil(EntryKey(name: "key@with@at"))
    XCTAssertNil(EntryKey(name: "key[with]brackets"))
  }

  func testKeyTrimming() {
    // Keys should be trimmed
    XCTAssertEqual(EntryKey(name: "  key  ")?.name, "key")
    XCTAssertEqual(EntryKey(name: "\tkey\t")?.name, "key")
    XCTAssertEqual(EntryKey(name: "\nkey\n")?.name, "key")
  }

  func testCaseSensitivity() {
    // Keys should be case-sensitive
    let upperKey = EntryKey(name: "KEY")
    let lowerKey = EntryKey(name: "key")
    XCTAssertNotEqual(upperKey, lowerKey)
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class EntryValueTests: XCTestCase {
  func testMaxLength() {
    XCTAssertEqual(EntryValue.maxLength, 255)
  }

  func testAsString() {
    XCTAssertEqual(EntryValue(string: "foo")?.string, "foo")
  }

  func testCreate_AllowEntryValueWithMaxLength() {
    let value = String(repeating: "k", count: EntryValue.maxLength)
    XCTAssertEqual(EntryValue(string: value)?.string, value)
  }

  func testCreate_DisallowEntryValueOverMaxLength() {
    let value = String(repeating: "k", count: EntryValue.maxLength + 1)
    XCTAssertNil(EntryValue(string: value)?.string)
  }

  func testAllowAnyCharactersInValue() {
    let value = String("\0") // null character
    XCTAssertNotNil(EntryValue(string: value))

    let unicodeValue = "Amélie" // unicode character
    XCTAssertNotNil(EntryValue(string: unicodeValue))

    let specialChars = "!@#$%^&*()" // special characters
    XCTAssertNotNil(EntryValue(string: specialChars))
  }

  func testEntryValueEquals() {
    XCTAssertEqual(EntryValue(string: "foo"), EntryValue(string: "foo"))
    XCTAssertNotEqual(EntryValue(string: "foo"), EntryValue(string: "bar"))
  }
}

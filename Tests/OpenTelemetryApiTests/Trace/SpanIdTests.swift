/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import XCTest

final class SpanIdTests: XCTestCase, @unchecked Sendable {
  let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]
  let secondBytes: [UInt8] = [0xFF, 0, 0, 0, 0, 0, 0, UInt8(ascii: "A")]

  var first: SpanId!
  var second: SpanId!

  override func setUp() {
    first = SpanId(fromBytes: firstBytes)
    second = SpanId(fromBytes: secondBytes)
  }

  func testIsValid() {
    XCTAssertFalse(SpanId.invalid.isValid)
    XCTAssertTrue(first.isValid)
    XCTAssertTrue(second.isValid)
  }

  func testFromHexString() {
    XCTAssertEqual(SpanId(fromHexString: "0000000000000000"), SpanId.invalid)
    XCTAssertEqual(SpanId(fromHexString: "0000000000000061"), first)
    XCTAssertEqual(SpanId(fromHexString: "ff00000000000041"), second)
  }

  func testFromHexString_WithOffset() {
    XCTAssertEqual(SpanId(fromHexString: "XX0000000000000000AA", withOffset: 2), SpanId.invalid)
    XCTAssertEqual(SpanId(fromHexString: "YY0000000000000061BB", withOffset: 2), first)
    XCTAssertEqual(SpanId(fromHexString: "ZZff00000000000041CC", withOffset: 2), second)
  }

  func testToHexString() {
    XCTAssertEqual(SpanId.invalid.hexString, "0000000000000000")
    XCTAssertEqual(first.hexString, "0000000000000061")
    XCTAssertEqual(second.hexString, "ff00000000000041")
  }

  func testSpanId_CompareTo() {
    XCTAssertLessThan(first, second)
    XCTAssertGreaterThan(second, first)
    XCTAssertEqual(first, SpanId(fromBytes: firstBytes))
  }

  func testSpanId_EqualsAndHashCode() {
    XCTAssertEqual(SpanId.invalid, SpanId.invalid)
    XCTAssertNotEqual(SpanId.invalid, first)
    XCTAssertNotEqual(SpanId.invalid, SpanId(fromBytes: firstBytes))
    XCTAssertNotEqual(SpanId.invalid, second)
    XCTAssertNotEqual(SpanId.invalid, SpanId(fromBytes: secondBytes))
    XCTAssertEqual(first, SpanId(fromBytes: firstBytes))
    XCTAssertNotEqual(first, second)
    XCTAssertNotEqual(first, SpanId(fromBytes: secondBytes))
    XCTAssertEqual(second, SpanId(fromBytes: secondBytes))
  }

  func testSpanId_ToString() {
    XCTAssertTrue(SpanId.invalid.description.contains("0000000000000000"))
    XCTAssertTrue(first.description.contains("0000000000000061"))
    XCTAssertTrue(second.description.contains("ff00000000000041"))
  }

  func testSpanId_Codable() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    XCTAssertEqual(SpanId.invalid, try decoder.decode(SpanId.self, from: encoder.encode(SpanId.invalid)))
    XCTAssertEqual(first, try decoder.decode(SpanId.self, from: encoder.encode(first)))
    XCTAssertEqual(second, try decoder.decode(SpanId.self, from: encoder.encode(second)))
  }

  static let allTests = [
    ("testIsValid", testIsValid),
    ("testFromHexString", testFromHexString),
    ("testToHexString", testToHexString),
    ("testToHexString", testToHexString),
    ("testSpanId_CompareTo", testSpanId_CompareTo),
    ("testSpanId_EqualsAndHashCode", testSpanId_EqualsAndHashCode),
    ("testSpanId_ToString", testSpanId_ToString),
    ("testSpanId_Codable", testSpanId_Codable)
  ]
}

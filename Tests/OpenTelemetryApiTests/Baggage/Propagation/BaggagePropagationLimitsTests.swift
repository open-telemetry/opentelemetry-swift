/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class BaggagePropagationLimitsTests: XCTestCase {
  func testMaxEntries() throws {
    var limits = BaggagePropagationLimits()
    for index in 0 ..< BaggagePropagationLimits.maxEntries {
      XCTAssertTrue(try limits.accept(key: XCTUnwrap(EntryKey(name: "k\(index)")), value: XCTUnwrap(EntryValue(string: "v"))))
    }

    XCTAssertFalse(try limits.accept(key: XCTUnwrap(EntryKey(name: "one-too-many")), value: XCTUnwrap(EntryValue(string: "v"))))
    XCTAssertEqual(limits.entries, BaggagePropagationLimits.maxEntries)
  }

  func testMaxBytes() throws {
    var limits = BaggagePropagationLimits()
    let key = try XCTUnwrap(EntryKey(name: String(repeating: "k", count: 200))) // 200 + 200 = 400 bytes per entry
    let value = try XCTUnwrap(EntryValue(string: String(repeating: "v", count: 200)))
    for _ in 0 ..< 20 { // 8000 bytes
      XCTAssertTrue(limits.accept(key: key, value: value))
    }

    XCTAssertFalse(limits.accept(key: key, value: value)) // 8400 > 8192
    XCTAssertTrue(try limits.accept(key: XCTUnwrap(EntryKey(name: "k")), value: XCTUnwrap(EntryValue(string: String(repeating: "v", count: 191))))) // exactly 8192
    XCTAssertEqual(limits.bytes, BaggagePropagationLimits.maxBytes)
  }

  func testRefusedEntryNotCounted() throws {
    var limits = BaggagePropagationLimits()
    let key = try XCTUnwrap(EntryKey(name: String(repeating: "k", count: 200)))
    let value = try XCTUnwrap(EntryValue(string: String(repeating: "v", count: 200)))
    for _ in 0 ..< 20 {
      _ = limits.accept(key: key, value: value)
    }

    XCTAssertFalse(limits.accept(key: key, value: value))

    XCTAssertEqual(limits.entries, 20)
    XCTAssertEqual(limits.bytes, 8000)
  }

  func testCountsUTF8Bytes() throws {
    var limits = BaggagePropagationLimits()
    XCTAssertTrue(try limits.accept(key: XCTUnwrap(EntryKey(name: "k")), value: XCTUnwrap(EntryValue(string: "é")))) // 1 + 2 bytes

    XCTAssertEqual(limits.bytes, 3)
  }
}

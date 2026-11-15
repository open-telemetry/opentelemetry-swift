/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import XCTest

final class TraceFlagsTests: XCTestCase {
  let firstByte: UInt8 = 0xFF
  let secondByte: UInt8 = 1
  let thirdByte: UInt8 = 6

  func testGetByte() {
    XCTAssertEqual(TraceFlags().byte, 0)
    XCTAssertEqual(TraceFlags().settingIsSampled(false).byte, 0)
    XCTAssertEqual(TraceFlags().settingIsSampled(true).byte, 1)
    XCTAssertEqual(TraceFlags(fromByte: firstByte).byte, 255)
    XCTAssertEqual(TraceFlags(fromByte: secondByte).byte, 1)
    XCTAssertEqual(TraceFlags(fromByte: thirdByte).byte, 6)
  }

  func testIsSampled() {
    XCTAssertFalse(TraceFlags().sampled)
    XCTAssertTrue(TraceFlags().settingIsSampled(true).sampled)
  }

  func testIsRandom() {
    XCTAssertFalse(TraceFlags().random)
    XCTAssertTrue(TraceFlags().settingIsRandom(true).random)
  }

  func testFromByte() {
    XCTAssertEqual(TraceFlags(fromByte: firstByte).byte, firstByte)
    XCTAssertEqual(TraceFlags(fromByte: secondByte).byte, secondByte)
    XCTAssertEqual(TraceFlags(fromByte: thirdByte).byte, thirdByte)
  }

  func testFromBase16() {
    XCTAssertEqual(TraceFlags(fromHexString: "ff").hexString, "ff")
    XCTAssertEqual(TraceFlags(fromHexString: "01").hexString, "01")
    XCTAssertEqual(TraceFlags(fromHexString: "06").hexString, "06")
  }

  func testBuilder_FromOptions() {
    XCTAssertEqual(TraceFlags(fromByte: thirdByte).settingIsSampled(true).byte, 6 | 1)
    XCTAssertEqual(TraceFlags(fromByte: thirdByte).settingIsRandom(true).byte, 6 | 2)
  }

  func testTraceFlags_EqualsAndHashCode() {
    XCTAssertNotEqual(TraceFlags(), TraceFlags(fromByte: secondByte))
    XCTAssertNotEqual(TraceFlags(), TraceFlags().settingIsSampled(true))
    XCTAssertNotEqual(TraceFlags(), TraceFlags(fromByte: firstByte))
    XCTAssertEqual(TraceFlags(fromByte: secondByte), TraceFlags().settingIsSampled(true))
    XCTAssertNotEqual(TraceFlags(fromByte: secondByte), TraceFlags(fromByte: firstByte))
    XCTAssertNotEqual(TraceFlags().settingIsSampled(true), TraceFlags(fromByte: firstByte))
  }

  func testTraceFlags_ToString() {
    XCTAssert(TraceFlags().description.contains("sampled=false"))
    XCTAssert(TraceFlags().settingIsSampled(true).description.contains("sampled=true"))
    XCTAssert(TraceFlags().description.contains("random=false"))
    XCTAssert(TraceFlags().settingIsRandom(true).description.contains("random=true"))
  }

  func testTraceFlags_Codabe() {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    var traceFlags = TraceFlags()
    XCTAssertEqual(traceFlags, try decoder.decode(TraceFlags.self, from: encoder.encode(traceFlags)))

    traceFlags = TraceFlags().settingIsSampled(true)
    XCTAssertEqual(traceFlags, try decoder.decode(TraceFlags.self, from: encoder.encode(traceFlags)))

    traceFlags = TraceFlags().settingIsSampled(false)
    XCTAssertEqual(traceFlags, try decoder.decode(TraceFlags.self, from: encoder.encode(traceFlags)))

    traceFlags = TraceFlags(fromByte: firstByte)
    XCTAssertEqual(traceFlags, try decoder.decode(TraceFlags.self, from: encoder.encode(traceFlags)))

    traceFlags = TraceFlags(fromByte: secondByte)
    XCTAssertEqual(traceFlags, try decoder.decode(TraceFlags.self, from: encoder.encode(traceFlags)))

    traceFlags = TraceFlags(fromByte: thirdByte)
    XCTAssertEqual(traceFlags, try decoder.decode(TraceFlags.self, from: encoder.encode(traceFlags)))
  }
}

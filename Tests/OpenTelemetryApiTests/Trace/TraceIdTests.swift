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

final class TraceIdTests: XCTestCase {
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]
    let secondBytes: [UInt8] = [0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "A")]
    let shortBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "b")]

    var first: TraceId!
    var second: TraceId!
    var short: TraceId!

    override func setUp() {
        first = TraceId(fromBytes: firstBytes)
        second = TraceId(fromBytes: secondBytes)
        short = TraceId(fromBytes: shortBytes)
    }

    func testInvalidTraceId() {
        XCTAssertEqual(TraceId.invalid.idLo, 0)
    }

    func testIsValid() {
        XCTAssertFalse(TraceId.invalid.isValid)
        XCTAssertTrue(first.isValid)
        XCTAssertTrue(second.isValid)
        XCTAssertTrue(short.isValid)
    }

    func testGetHigherLong() {
        XCTAssertEqual(first.rawHigherLong, 0)
        XCTAssertEqual(second.rawHigherLong, 0xFF00000000000000)
    }

    func testGetLowerLong() {
        XCTAssertEqual(first.rawLowerLong, 0x61)
        XCTAssertEqual(second.rawLowerLong, 0x41)
    }

    func testFromHexString() {
        XCTAssertEqual(TraceId(fromHexString: "00000000000000000000000000000000"), TraceId.invalid)
        XCTAssertEqual(TraceId(fromHexString: "00000000000000000000000000000061"), first)
        XCTAssertEqual(TraceId(fromHexString: "ff000000000000000000000000000041"), second)
        XCTAssertEqual(TraceId(fromHexString: "0000000000000062"), short)
    }

    func testFromHexString_WithOffset() {
        XCTAssertEqual(TraceId(fromHexString: "XX00000000000000000000000000000000CC", withOffset: 2), TraceId.invalid)
        XCTAssertEqual(TraceId(fromHexString: "YY00000000000000000000000000000061AA", withOffset: 2), first)
        XCTAssertEqual(TraceId(fromHexString: "ZZff000000000000000000000000000041BB", withOffset: 2), second)
        XCTAssertEqual(TraceId(fromHexString: "ZZ0000000000000062AA", withOffset: 2), short)
    }

    func testToHexString() {
        XCTAssertEqual(TraceId.invalid.hexString, "00000000000000000000000000000000")
        XCTAssertEqual(first.hexString, "00000000000000000000000000000061")
        XCTAssertEqual(second.hexString, "ff000000000000000000000000000041")
        XCTAssertEqual(short.hexString, "00000000000000000000000000000062")
    }

    func testTraceId_CompareTo() {
        XCTAssertLessThan(first, second)
        XCTAssertGreaterThan(second, first)
        XCTAssertEqual(first, TraceId(fromBytes: firstBytes))
    }

    func testTraceId_EqualsAndHashCode() {
        XCTAssertEqual(TraceId.invalid, TraceId.invalid)
        XCTAssertNotEqual(TraceId.invalid, first)
        XCTAssertNotEqual(TraceId.invalid, TraceId(fromBytes: firstBytes))
        XCTAssertNotEqual(TraceId.invalid, second)
        XCTAssertNotEqual(TraceId.invalid, TraceId(fromBytes: secondBytes))
        XCTAssertNotEqual(TraceId.invalid, short)
        XCTAssertNotEqual(TraceId.invalid, TraceId(fromBytes: shortBytes))
        XCTAssertEqual(first, TraceId(fromBytes: firstBytes))
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, TraceId(fromBytes: secondBytes))
        XCTAssertNotEqual(first, short)
        XCTAssertNotEqual(first, TraceId(fromBytes: shortBytes))
        XCTAssertEqual(second, TraceId(fromBytes: secondBytes))
        XCTAssertNotEqual(second, short)
        XCTAssertNotEqual(second, TraceId(fromBytes: shortBytes))
        XCTAssertEqual(short, TraceId(fromBytes: shortBytes))
    }

    func testTraceId_ToString() {
        XCTAssertTrue(TraceId.invalid.description.contains("00000000000000000000000000000000"))
        XCTAssertTrue(first.description.contains("00000000000000000000000000000061"))
        XCTAssertTrue(second.description.contains("ff000000000000000000000000000041"))
        XCTAssertTrue(short.description.contains("0000000000000062"))
    }

    static var allTests = [
        ("testInvalidTraceId", testInvalidTraceId),
        ("testInvalidTraceId", testInvalidTraceId),
        ("testIsValid", testIsValid),
        ("testGetLowerLong", testGetLowerLong),
        ("testFromHexString", testFromHexString),
        ("testFromHexString_WithOffset", testFromHexString_WithOffset),
        ("testToHexString", testToHexString),
        ("testTraceId_CompareTo", testTraceId_CompareTo),
        ("testTraceId_EqualsAndHashCode", testTraceId_EqualsAndHashCode),
        ("testTraceId_ToString", testTraceId_ToString),
    ]
}

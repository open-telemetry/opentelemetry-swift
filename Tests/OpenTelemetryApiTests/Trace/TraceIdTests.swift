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

@testable import OpenTelemetryApi
import XCTest

final class TraceIdTests: XCTestCase {
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]
    let secondBytes: [UInt8] = [0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "A")]

    var first: TraceId!
    var second: TraceId!

    override func setUp() {
        first = TraceId(fromBytes: firstBytes)
        second = TraceId(fromBytes: secondBytes)
    }

    func testInvalidTraceId() {
        XCTAssertEqual(TraceId.invalid.idLo, 0)
    }

    func testIsValid() {
        XCTAssertFalse(TraceId.invalid.isValid)
        XCTAssertTrue(first.isValid)
        XCTAssertTrue(second.isValid)
    }

    func testGetLowerLong() {
        XCTAssertEqual(first.lowerLong, 0)
        XCTAssertEqual(second.lowerLong, 0xFF00000000000000)
    }

    func testFromHexString() {
        XCTAssertEqual(TraceId(fromHexString: "00000000000000000000000000000000"), TraceId.invalid)
        XCTAssertEqual(TraceId(fromHexString: "00000000000000000000000000000061"), first)
        XCTAssertEqual(TraceId(fromHexString: "ff000000000000000000000000000041"), second)
    }

    func testFromHexString_WithOffset() {
        XCTAssertEqual(TraceId(fromHexString: "XX00000000000000000000000000000000CC", withOffset: 2), TraceId.invalid)
        XCTAssertEqual(TraceId(fromHexString: "YY00000000000000000000000000000061AA", withOffset: 2), first)
        XCTAssertEqual(TraceId(fromHexString: "ZZff000000000000000000000000000041BB", withOffset: 2), second)
    }

    func testToHexString() {
        XCTAssertEqual(TraceId.invalid.hexString, "00000000000000000000000000000000")
        XCTAssertEqual(first.hexString, "00000000000000000000000000000061")
        XCTAssertEqual(second.hexString, "ff000000000000000000000000000041")
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
        XCTAssertEqual(first, TraceId(fromBytes: firstBytes))
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, TraceId(fromBytes: secondBytes))
        XCTAssertEqual(second, TraceId(fromBytes: secondBytes))
    }

    func testTraceId_ToString() {
        XCTAssertTrue(TraceId.invalid.description.contains("00000000000000000000000000000000"))
        XCTAssertTrue(first.description.contains("00000000000000000000000000000061"))
        XCTAssertTrue(second.description.contains("ff000000000000000000000000000041"))
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

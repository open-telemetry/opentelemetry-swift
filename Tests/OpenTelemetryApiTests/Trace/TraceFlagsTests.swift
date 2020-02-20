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
    }
}

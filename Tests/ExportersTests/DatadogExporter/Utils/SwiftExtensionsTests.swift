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

@testable import DatadogExporter
import XCTest

class TimeIntervalExtensionTests: XCTestCase {
    func testTimeIntervalSince1970InMilliseconds() {
        let date15Dec2019 = Date.mockDecember15th2019At10AMUTC()
        XCTAssertEqual(date15Dec2019.timeIntervalSince1970.toMilliseconds, 1_576_404_000_000)

        let dateAdvanced = date15Dec2019 + 9.999
        XCTAssertEqual(dateAdvanced.timeIntervalSince1970.toMilliseconds, 1_576_404_009_999)

        let dateAgo = date15Dec2019 - 0.001
        XCTAssertEqual(dateAgo.timeIntervalSince1970.toMilliseconds, 1_576_403_999_999)

        let overflownDate = Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude)
        XCTAssertEqual(overflownDate.timeIntervalSince1970.toMilliseconds, UInt64.max)

        let uInt64MaxDate = Date(timeIntervalSinceReferenceDate: TimeInterval(UInt64.max))
        XCTAssertEqual(uInt64MaxDate.timeIntervalSince1970.toMilliseconds, UInt64.max)
    }

    func testTimeIntervalSince1970InNanoseconds() {
        let date15Dec2019 = Date.mockDecember15th2019At10AMUTC()
        XCTAssertEqual(date15Dec2019.timeIntervalSince1970.toNanoseconds, 1_576_404_000_000_000_000)

        // As `TimeInterval` yields sub-millisecond precision this rounds up to the nearest millisecond:
        let dateAdvanced = date15Dec2019 + 9.999_999_999
        XCTAssertEqual(dateAdvanced.timeIntervalSince1970.toNanoseconds, 1_576_404_010_000_000_000)

        // As `TimeInterval` yields sub-millisecond precision this rounds up to the nearest millisecond:
        let dateAgo = date15Dec2019 - 0.000_000_001
        XCTAssertEqual(dateAgo.timeIntervalSince1970.toNanoseconds, 1_576_404_000_000_000_000)

        let overflownDate = Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude)
        XCTAssertEqual(overflownDate.timeIntervalSince1970.toNanoseconds, UInt64.max)

        let uInt64MaxDate = Date(timeIntervalSinceReferenceDate: TimeInterval(UInt64.max))
        XCTAssertEqual(uInt64MaxDate.timeIntervalSince1970.toNanoseconds, UInt64.max)
    }
}

class IntegerOverflowExtensionTests: XCTestCase {
    func testHappyPath() {
        let reasonableDouble = Double(1_000.123_456)

        XCTAssertNoThrow(try UInt64(withReportingOverflow: reasonableDouble))
        XCTAssertEqual(try UInt64(withReportingOverflow: reasonableDouble), 1_000)
    }

    func testNegative() {
        let negativeDouble = Double(-1_000.123_456)

        XCTAssertThrowsError(try UInt64(withReportingOverflow: negativeDouble)) { error in
            XCTAssertTrue(error is FixedWidthIntegerError<Double>)
            if case let FixedWidthIntegerError.overflow(overflowingValue) = (error as! FixedWidthIntegerError<Double>) {
                XCTAssertEqual(overflowingValue, negativeDouble)
            }
        }
    }

    func testFloat() {
        let simpleFloat = Float(222.123_456)

        XCTAssertNoThrow(try UInt8(withReportingOverflow: simpleFloat))
        XCTAssertEqual(try UInt8(withReportingOverflow: simpleFloat), 222)
    }

    func testGreatestFiniteMagnitude() {
        let almostInfinity = Double.greatestFiniteMagnitude

        XCTAssertThrowsError(try UInt64(withReportingOverflow: almostInfinity)) { error in
            XCTAssertTrue(error is FixedWidthIntegerError<Double>)
        }
    }

    func testInfinity() {
        let infinityAndBeyond = Double.infinity

        XCTAssertThrowsError(try UInt64(withReportingOverflow: infinityAndBeyond)) { error in
            XCTAssertTrue(error is FixedWidthIntegerError<Double>)
        }
    }

    func testCornerCase() {
        let uInt64Max = Double(UInt64.max)

        XCTAssertThrowsError(try UInt64(withReportingOverflow: uInt64Max)) { error in
            XCTAssertTrue(error is FixedWidthIntegerError<Double>)
            if case let FixedWidthIntegerError.overflow(overflowingValue) = (error as! FixedWidthIntegerError<Double>) {
                XCTAssertEqual(overflowingValue, uInt64Max)
            }
        }
    }
}

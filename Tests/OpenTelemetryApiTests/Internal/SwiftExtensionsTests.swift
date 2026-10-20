/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

extension Date {
  static func mockSpecificUTCGregorianDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, second: Int = 0) -> Date {
    var dateComponents = DateComponents()
    dateComponents.year = year
    dateComponents.month = month
    dateComponents.day = day
    dateComponents.hour = hour
    dateComponents.minute = minute
    dateComponents.second = second
    dateComponents.timeZone = TimeZone(abbreviation: "UTC")
    dateComponents.calendar = Calendar(identifier: .gregorian)
    return dateComponents.date!
  }

  static func mockDecember15th2019At10AMUTC(addingTimeInterval timeInterval: TimeInterval = 0) -> Date {
    return mockSpecificUTCGregorianDate(year: 2_019, month: 12, day: 15, hour: 10)
      .addingTimeInterval(timeInterval)
  }
}

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

    // Negative overflow also caps to .max for UInt64
    let underflownDate = Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude * -1)
    XCTAssertEqual(underflownDate.timeIntervalSince1970.toMilliseconds, UInt64.max)

    let int64MaxDate = Date(timeIntervalSinceReferenceDate: TimeInterval(Int64.max))
    XCTAssertEqual(int64MaxDate.timeIntervalSince1970.toMilliseconds, UInt64.max)

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

    // Negative overflow also caps to .max for UInt64
    let underflownDate = Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude * -1)
    XCTAssertEqual(underflownDate.timeIntervalSince1970.toNanoseconds, UInt64.max)

    let int64MaxDate = Date(timeIntervalSinceReferenceDate: TimeInterval(Int64.max))
    XCTAssertEqual(int64MaxDate.timeIntervalSince1970.toNanoseconds, UInt64.max)

    let uInt64MaxDate = Date(timeIntervalSinceReferenceDate: TimeInterval(UInt64.max))
    XCTAssertEqual(uInt64MaxDate.timeIntervalSince1970.toNanoseconds, UInt64.max)
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class DateProviderTests: XCTestCase {
  var dateProvider: DateProvider!

  override func setUp() {
    super.setUp()
    dateProvider = DateProvider()
  }

  override func tearDown() {
    dateProvider = nil
    super.tearDown()
  }

  func testISO8601StringFormat() {
    // Given
    let testDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC

    // When
    let iso8601String = dateProvider.iso8601String(from: testDate)

    // Then
    XCTAssertEqual(iso8601String, "2021-01-01T00:00:00.000Z")
  }

  func testDateFromISO8601String() {
    // Given
    let iso8601String = "2021-01-01T00:00:00.000Z"

    // When
    let date = dateProvider.date(fromISO8601String: iso8601String)

    // Then
    XCTAssertNotNil(date)
    XCTAssertEqual(date?.timeIntervalSince1970, 1609459200)
  }

  func testInvalidDateFromISO8601String() {
    // Given
    let invalidString = "not-a-date"

    // When
    let date = dateProvider.date(fromISO8601String: invalidString)

    // Then
    XCTAssertNil(date)
  }

  func testCurrentDateIsRecentAndInUTC() {
    // Given
    let beforeTest = Date()

    // When
    let currentDate = dateProvider.currentDate()
    let afterTest = Date()

    // Then
    XCTAssertGreaterThanOrEqual(currentDate, beforeTest)
    XCTAssertLessThanOrEqual(currentDate, afterTest)

    // Verify UTC formatting
    let iso8601String = dateProvider.iso8601String(from: currentDate)
    XCTAssertTrue(iso8601String.hasSuffix("Z"), "ISO8601 string should end with Z indicating UTC timezone")
  }
}

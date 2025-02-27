/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class DateFormattingTests: XCTestCase {
  private let date: Date = .mockDecember15th2019At10AMUTC(addingTimeInterval: 0.001)

  func testISO8601DateFormatter() {
    XCTAssertEqual(iso8601DateFormatter.string(from: date),
                   "2019-12-15T10:00:00.001Z")
  }
}

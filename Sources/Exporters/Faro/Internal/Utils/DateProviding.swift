/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Protocol for providing current date, making it easier to test time-dependent logic
protocol DateProviding {
  /// Returns the current date
  func currentDate() -> Date

  /// Converts a specific date to ISO 8601 format with milliseconds precision
  func iso8601String(from date: Date) -> String

  /// Converts an ISO 8601 string to a date
  func date(fromISO8601String string: String) -> Date?
}

/// Default implementation of DateProviding that returns the actual current date
class DateProvider: DateProviding {
  private let iso8601Formatter: ISO8601DateFormatter

  init() {
    iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    iso8601Formatter.timeZone = TimeZone(secondsFromGMT: 0)
  }

  func currentDate() -> Date {
    return Date()
  }

  func iso8601String(from date: Date) -> String {
    return iso8601Formatter.string(from: date)
  }

  func date(fromISO8601String string: String) -> Date? {
    return iso8601Formatter.date(from: string)
  }
}

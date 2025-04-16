/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Protocol for providing current date, making it easier to test time-dependent logic
protocol DateProviding {
  /// Returns the current date
  func currentDate() -> Date

  /// Returns the current date as a string in ISO 8601 format with milliseconds precision (YYYY-MM-DDTHH:mm:ss.sssZ)
  func currentDateISO8601String() -> String
  
  /// Converts a specific date to ISO 8601 format with milliseconds precision
  func iso8601String(from date: Date) -> String
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

  func currentDateISO8601String() -> String {
    return iso8601Formatter.string(from: currentDate())
  }
  
  func iso8601String(from date: Date) -> String {
    return iso8601Formatter.string(from: date)
  }
}

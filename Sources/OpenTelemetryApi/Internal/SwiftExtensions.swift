/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public extension TimeInterval {
  /// `TimeInterval` represented in milliseconds (capped to `UInt64.max`).
  var toMilliseconds: UInt64 {
    let milliseconds = self * 1_000
    return UInt64(withReportingOverflow: milliseconds) ?? .max
  }

  var toMicroseconds: UInt64 {
    let microseconds = self * 1_000_000
    return UInt64(withReportingOverflow: microseconds) ?? .max
  }

  /// `TimeInterval` represented in nanoseconds (capped to `UInt64.max`).
  var toNanoseconds: UInt64 {
    let nanoseconds = self * 1_000_000_000
    return UInt64(withReportingOverflow: nanoseconds) ?? .max
  }

  static func fromMilliseconds(_ millis: Int64) -> TimeInterval {
    return Double(millis) / 1_000
  }

  static func fromMicroseconds(_ micros: Int64) -> TimeInterval {
    return Double(micros) / 1_000_000
  }

  static func fromNanoseconds(_ nanos: Int64) -> TimeInterval {
    return Double(nanos) / 1_000_000_000
  }
}

private extension FixedWidthInteger {
  init?(withReportingOverflow floatingPoint: some BinaryFloatingPoint) {
    guard let converted = Self(exactly: floatingPoint.rounded()) else {
      return nil
    }
    self = converted
  }
}

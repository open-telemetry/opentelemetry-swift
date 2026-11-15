/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Global public extensions on `TimeInterval`.
///
/// - Important: These are public API surface on a Foundation type. Any signature change
///   (including return type) is a **source-breaking change** for all downstream consumers,
///   not just `opentelemetry-swift`. Changing these requires a **major version bump**.
public extension TimeInterval {
  /// `TimeInterval` represented in milliseconds (capped to `UInt64.max`).
  /// - Warning: Changing the return type is source-breaking. Requires a major version bump.
  var toMilliseconds: UInt64 {
    let milliseconds = self * 1_000
    return UInt64(withReportingOverflow: milliseconds) ?? .max
  }

  /// `TimeInterval` represented in microseconds (capped to `UInt64.max`).
  /// - Warning: Changing the return type is source-breaking. Requires a major version bump.
  var toMicroseconds: UInt64 {
    let microseconds = self * 1_000_000
    return UInt64(withReportingOverflow: microseconds) ?? .max
  }

  /// `TimeInterval` represented in nanoseconds (capped to `UInt64.max`).
  /// - Warning: Changing the return type is source-breaking. Requires a major version bump.
  var toNanoseconds: UInt64 {
    let nanoseconds = self * 1_000_000_000
    return UInt64(withReportingOverflow: nanoseconds) ?? .max
  }

  /// - Warning: Changing the parameter type is source-breaking. Requires a major version bump.
  static func fromMilliseconds(_ millis: Int64) -> TimeInterval {
    return Double(millis) / 1_000
  }

  /// - Warning: Changing the parameter type is source-breaking. Requires a major version bump.
  static func fromMicroseconds(_ micros: Int64) -> TimeInterval {
    return Double(micros) / 1_000_000
  }

  /// - Warning: Changing the parameter type is source-breaking. Requires a major version bump.
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

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Interface for getting the current time.
public protocol Clock: AnyObject {
  /// Obtains the current time for this clock.
  var now: Date { get }

  /// Returns a monotonic counter in nanos that can only be used to measure time durations.
  var monotonicNanos: Int64 { get }

  /// Returns the approximate time in nanoseconds since 1970.
  /// This time will not be precise, because Date doesn't use 1970 as its reference date, and also
  /// the double TimeInterval used internall does not have enough precision for nanos.
  var nanoTime: UInt64 { get }
}

public extension Clock {
  var nanoTime: UInt64 { return now.timeIntervalSince1970.toNanoseconds }

  var monotonicNanos: Int64 {
    // Converting this from UInt64 to Int64 means that there will be an overflow
    // if the device is up for Int64.max nanoseconds, which is about 292 years.
    return Int64(DispatchTime.now().uptimeNanoseconds)
  }
}

public func == (lhs: Clock, rhs: Clock) -> Bool {
  return lhs.nanoTime == rhs.nanoTime
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// A mutable Clock that allows the time to be set for testing.
class TestClock: Clock {
  var currentTimeInterval: TimeInterval

  /// Creates a clock with the given time.
  /// - Parameter nanos: the initial time since epoch.
  init(timeInterval: TimeInterval) {
    currentTimeInterval = timeInterval
  }

  /// Creates a clock with the given time.
  /// - Parameter nanos: the initial time in nanos since epoch.
  init(nanos: UInt64) {
    currentTimeInterval = Double(nanos) / 1000000000
  }

  /// Creates a clock initialized to a constant non-zero time
  convenience init() {
    self.init(timeInterval: Date(timeIntervalSinceReferenceDate: 0).timeIntervalSince1970)
  }

  ///  Sets the time.
  /// - Parameter timeInterval: the new time.
  func setTime(timeInterval: TimeInterval) {
    currentTimeInterval = timeInterval
  }

  ///  Sets the time.
  /// - Parameter nanos: the new time.
  func setTime(nanos: Int64) {
    currentTimeInterval = TimeInterval.fromNanoseconds(nanos)
  }

  /// Advances the time by millis and mutates this instance.
  /// - Parameter millis: the increase in time.
  func advanceMillis(_ millis: Int64) {
    currentTimeInterval += TimeInterval.fromMilliseconds(millis)
  }

  /// Advances the time by nanos and mutates this instance.
  /// - Parameter nanos: the increase in time
  func advanceNanos(_ nanos: Int64) {
    currentTimeInterval += TimeInterval.fromNanoseconds(nanos)
  }

  var now: Date {
    return Date(timeIntervalSince1970: currentTimeInterval)
  }
}

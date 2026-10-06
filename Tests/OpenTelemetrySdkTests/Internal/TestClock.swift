/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// A mutable Clock that allows the time to be set for testing.
class TestClock: Clock {
  var currentTimeInterval: TimeInterval
  var monotonicNanos: Int64

  /// Creates a clock with the given time.
  /// - Parameter timeInterval: the initial time since epoch.
  init(timeInterval: TimeInterval) {
    currentTimeInterval = timeInterval
    monotonicNanos = 0
  }

  /// Creates a clock with the given time.
  /// - Parameter nanos: the initial time in nanos since epoch.
  init(nanos: Int64) {
    currentTimeInterval = Double(nanos) / 1_000_000_000
    monotonicNanos = nanos - Int64(currentTimeInterval * 1_000_000_000)
  }

  /// Creates a clock initialized to a constant non-zero time
  convenience init() {
    self.init(timeInterval: Date(timeIntervalSinceReferenceDate: 0).timeIntervalSince1970)
  }

  ///  Sets the time.
  /// - Parameter timeInterval: the new time.
  func setTime(timeInterval: TimeInterval) {
    currentTimeInterval = timeInterval
    monotonicNanos = 0
  }

  ///  Sets the time.
  /// - Parameter nanos: the new time.
  func setTime(nanos: Int64) {
    currentTimeInterval = Double(nanos) / 1_000_000_000
    monotonicNanos = nanos - Int64(currentTimeInterval * 1_000_000_000)
  }

  /// Advances the time by millis and mutates this instance.
  /// - Parameter millis: the increase in time.
  func advanceMillis(_ millis: Int64) {
    monotonicNanos += Int64(abs(millis)) * 1_000_000
  }

  /// Advances the time by nanos and mutates this instance.
  /// - Parameter nanos: the increase in time
  func advanceNanos(_ nanos: Int64) {
    monotonicNanos += Int64(abs(nanos))
  }

  var nanoTime: UInt64 {
    let result = Int64(currentTimeInterval.toNanoseconds) + monotonicNanos
    return result < 0 ? 0 : UInt64(result)
  }

  var now: Date {
    return Date(timeIntervalSince1970: TimeInterval.fromNanoseconds(Int64(nanoTime)))
  }
}

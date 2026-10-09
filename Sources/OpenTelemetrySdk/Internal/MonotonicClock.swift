/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// A clock that provides monotonic time tracking by combining wall clock time with DispatchTime.
/// This clock is immune to system clock adjustments (NTP, user changes, etc.) and never goes backwards.
///
/// This clock should be re-created periodically to re-sync with the system clock, as it tracks
/// elapsed time from initialization and can drift from actual wall clock time over long periods.
public class MonotonicClock: Clock {
  let clock: Clock
  let initialWallTimeNanos: Int64
  let initialMonotonicNanos: Int64

  public init(clock: Clock) {
    self.clock = clock

    // Capture both wall time and monotonic time as close together as possible
    self.initialWallTimeNanos = Int64(clock.nanoTime)
    self.initialMonotonicNanos = clock.monotonicNanos
  }

  public var nanoTime: UInt64 {
    // Adjust the initial wall time by however many nanos have passed since then.
    let currentMonotonicNanos = clock.monotonicNanos
    let elapsedNanos = currentMonotonicNanos - initialMonotonicNanos
    let result = initialWallTimeNanos + elapsedNanos
    return result < 0 ? 0 : UInt64(result)
  }

  public var now: Date {
    let seconds = TimeInterval(self.nanoTime) / 1_000_000_000
    return Date(timeIntervalSince1970: seconds)
  }
}

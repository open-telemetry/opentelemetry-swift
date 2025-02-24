/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// This class provides a mechanism for calculating the epoch time using a reference date
/// This clock needs to be re-created periodically in order to re-sync with the kernel clock, and
/// it is not recommended to use only one instance for a very long period of time.
public class MonotonicClock: Clock {
  let clock: Clock
  let epoch: Date
  let initialTime: Date

  public init(clock: Clock) {
    self.clock = clock
    epoch = clock.now
    initialTime = clock.now
  }

  public var now: Date {
    let delta = clock.now.timeIntervalSince(initialTime)
    return epoch.addingTimeInterval(delta)
  }
}

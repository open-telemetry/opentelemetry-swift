/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

protocol Delay {
  var current: TimeInterval { get }
  mutating func decrease()
  mutating func increase()
}

/// Mutable interval used for periodic data uploads.
struct DataUploadDelay: Delay {
  private let defaultDelay: TimeInterval
  private let minDelay: TimeInterval
  private let maxDelay: TimeInterval
  private let changeRate: Double

  private var delay: TimeInterval

  init(performance: UploadPerformancePreset) {
    defaultDelay = performance.defaultUploadDelay
    minDelay = performance.minUploadDelay
    maxDelay = performance.maxUploadDelay
    changeRate = performance.uploadDelayChangeRate
    delay = performance.initialUploadDelay
  }

  var current: TimeInterval { delay }

  mutating func decrease() {
    delay = max(minDelay, delay * (1.0 - changeRate))
  }

  mutating func increase() {
    delay = min(delay * (1.0 + changeRate), maxDelay)
  }
}

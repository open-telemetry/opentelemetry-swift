/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

internal protocol Delay {
    var current: TimeInterval { get }
    mutating func decrease()
    mutating func increase()
}

/// Mutable interval used for periodic data uploads.
internal struct DataUploadDelay: Delay {
    private let defaultDelay: TimeInterval
    private let minDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let changeRate: Double

    private var delay: TimeInterval

    init(performance: UploadPerformancePreset) {
        self.defaultDelay = performance.defaultUploadDelay
        self.minDelay = performance.minUploadDelay
        self.maxDelay = performance.maxUploadDelay
        self.changeRate = performance.uploadDelayChangeRate
        self.delay = performance.initialUploadDelay
    }

    var current: TimeInterval { delay }

    mutating func decrease() {
        delay = max(minDelay, delay * (1.0 - changeRate))
    }

    mutating func increase() {
        delay = min(delay * (1.0 + changeRate), maxDelay)
    }
}

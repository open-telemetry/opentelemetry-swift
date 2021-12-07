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

/// Mutable interval used for periodic data exports.
internal struct DataExportDelay: Delay {
    private let defaultDelay: TimeInterval
    private let minDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let changeRate: Double

    private var delay: TimeInterval

    init(performance: ExportPerformancePreset) {
        self.defaultDelay = performance.defaultExportDelay
        self.minDelay = performance.minExportDelay
        self.maxDelay = performance.maxExportDelay
        self.changeRate = performance.exportDelayChangeRate
        self.delay = performance.initialExportDelay
    }

    var current: TimeInterval { delay }

    mutating func decrease() {
        delay = max(minDelay, delay * (1.0 - changeRate))
    }

    mutating func increase() {
        delay = min(delay * (1.0 + changeRate), maxDelay)
    }
}

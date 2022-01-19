/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Bound measure metric
open class BoundMeasureMetric<T> {
    public init() {}

    /// Record the given value to the bound measure metric.
    /// - Parameters:
    ///   - value: the measurement to be recorded.
    open func record(value: T) {
    }
}

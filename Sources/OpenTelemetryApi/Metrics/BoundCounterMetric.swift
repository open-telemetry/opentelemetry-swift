/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Bound counter metric
open class BoundCounterMetric<T> {
    public init() {}

    /// Adds the given value to the bound counter metric.
    /// - Parameters:
    ///   - value: value by which the bound counter metric should be added
    open func add(value: T) {
        fatalError()
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Bound histogram metric
open class BoundHistogramMetric<T> {
    public init(explicitBoundaries: Array<T>? = nil) {}

    /// Record the given value to the bound histogram metric.
    /// - Parameters:
    ///   - value: the histogram to be recorded.
    open func record(value: T) {
    }
    

}

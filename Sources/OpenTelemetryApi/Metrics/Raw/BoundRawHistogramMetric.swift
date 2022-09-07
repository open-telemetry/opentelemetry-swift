/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

open class BoundRawHistogramMetric<T> {
    public init() {}
    
    /// record a raw histogarm metric
    /// - Parameters:
    ///     - explicitBoundaries: Array of boundies
    ///     - counts: Array of counts in each bucket
    ///     - startDate: the start of the time range of the histogram
    ///     - endDate : the end of the time range of the histogram
    open func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T) {}
    
}

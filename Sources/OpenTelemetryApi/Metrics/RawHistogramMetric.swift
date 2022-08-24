/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */


import Foundation

// Raw Histogram Metric
// use to record pre-aggregated data
public protocol RawHistogramMetric {
    associatedtype T
    /// record a raw histogarm metric
    /// - Parameters:
    ///     - explicitBoundaries: Array of boundies
    ///     - counts: Array of counts in each bucket
    ///     - startDate: the start of the time range of the histogram
    ///     - endDate : the end of the time range of the histogram
    func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T)
    
}



public struct AnyRawHistogramMetric<T> : RawHistogramMetric {
   
    let internalHistogram : Any
    private let _record: (Array<T>, Array<Int>, Date, Date, Int, T) -> Void
    
    public func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T) {
        _record(explicitBoundaries, counts, startDate, endDate, count, sum)
    }
    
    public init <U: RawHistogramMetric>(_ histogram: U) where U.T == T {
        internalHistogram =  histogram
        _record = histogram.record(explicitBoundaries:counts:startDate:endDate:count:sum:)
    }
}
     
public struct NoopRawHistogramMetric<T> : RawHistogramMetric {
    public func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T) {
        
    }
    
        public init() {}
}
                                     

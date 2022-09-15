/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */


import Foundation

// Raw Histogram Metric
// use to record pre-aggregated data
public protocol RawHistogramMetric {
    associatedtype T

    /// Gets the bound raw histogram metric with given labelset.
    /// - Parameters:
    ///   - labelset: The labelset from which bound instrument should be constructed.
    /// - Returns: The bound raw histogram metric.

    func bind(labelset: LabelSet) -> BoundRawHistogramMetric<T>
    
    /// Gets the bound histogram metric with given labelset.
    /// - Parameters:
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound histogram metric.
    func bind(labels: [String: String]) -> BoundRawHistogramMetric<T>
    
    /// record a raw histogarm metric
    /// - Parameters:
    ///     - explicitBoundaries: Array of boundies
    ///     - counts: Array of counts in each bucket
    ///     - startDate: the start of the time range of the histogram
    ///     - endDate : the end of the time range of the histogram
    ///     - labelset: The labelset from which bound instrument should be constructed.
    func record(explicitBoundaries: Array<T>,
                counts: Array<Int>,
                startDate: Date,
                endDate: Date,
                count: Int,
                sum: T,
                labelset: LabelSet) -> Void
//    {
//        bind(labelset: labelset).record(explicitBoundaries: explicitBoundaries, counts: counts, startDate: startDate, endDate: endDate, count: count, sum: sum)
//    }
    
    /// record a raw histogarm metric
    /// - Parameters:
    ///     - explicitBoundaries: Array of boundies
    ///     - counts: Array of counts in each bucket
    ///     - startDate: the start of the time range of the histogram
    ///     - endDate : the end of the time range of the histogram
    ///     - labels: the labels or dimensions associated with the histogram
    func record(explicitBoundaries: Array<T>,
                counts: Array<Int>,
                startDate: Date,
                endDate: Date,
                count: Int,
                sum: T,
                labels: [String:String]) -> Void
//    {
//
//            bind(labels:labels).record(explicitBoundaries: explicitBoundaries, counts: counts, startDate: startDate, endDate: endDate, count: count, sum: sum)
//    }
}


public struct AnyRawHistogramMetric<T> : RawHistogramMetric {
    let internalHistogram : Any
    
    private let _bindLabelSet: (LabelSet) -> BoundRawHistogramMetric<T>
    private let _bindLabels: ([String:String]) -> BoundRawHistogramMetric<T>
    private let _bindRecordLabelSet: (Array<T>, Array<Int>, Date, Date, Int, T, LabelSet) -> Void
    private let _bindRecordLabels: (Array<T>, Array<Int>, Date, Date, Int, T, [String:String]) -> Void
    
    
    public init <U: RawHistogramMetric>(_ histogram: U) where U.T == T {
        internalHistogram =  histogram
        _bindLabelSet = histogram.bind(labelset:)
        _bindLabels = histogram.bind(labels:)
        _bindRecordLabels = histogram.record(explicitBoundaries:counts:startDate:endDate:count:sum:labels:)
        _bindRecordLabelSet = histogram.record(explicitBoundaries:counts:startDate:endDate:count:sum:labelset:)
    }
    
    public func bind(labelset: LabelSet) -> BoundRawHistogramMetric<T> {
        _bindLabelSet(labelset)
    }
    
    public func bind(labels: [String : String]) -> BoundRawHistogramMetric<T> {
        _bindLabels(labels)
    }
    
    public func record(explicitBoundaries: Array<T>,
                       counts: Array<Int>,
                       startDate: Date,
                       endDate: Date,
                       count: Int,
                       sum: T,
                       labels: [String:String])  {
        _bindRecordLabels(explicitBoundaries, counts, startDate, endDate, count, sum, labels)
    }
    public func record(explicitBoundaries: Array<T>,
                       counts: Array<Int>,
                       startDate: Date,
                       endDate: Date,
                       count: Int,
                       sum: T,
                       labelset: LabelSet) {
        _bindRecordLabelSet(explicitBoundaries, counts, startDate, endDate, count, sum, labelset)
    }
}
     
public struct NoopRawHistogramMetric<T> : RawHistogramMetric {
    public func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T, labelset: LabelSet) {
                
    }
    
    public func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T, labels: [String : String]) {
        
    }
    
    
    public init() {}
    
    public func bind(labelset: LabelSet) -> BoundRawHistogramMetric<T> {
        BoundRawHistogramMetric<T>()
    }
    
    public func bind(labels: [String : String]) -> BoundRawHistogramMetric<T> {
        BoundRawHistogramMetric<T>()
    }
    
}
                                     

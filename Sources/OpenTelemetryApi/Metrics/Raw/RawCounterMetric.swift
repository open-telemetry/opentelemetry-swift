/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol RawCounterMetric {
    associatedtype T
    
    func record(sum: T, startDate : Date, endDate: Date, labels: [String:String])
    func record(sum: T, startDate : Date, endDate: Date, labelset: LabelSet)

    /// Gets the bound counter metric with given labelset.
    /// - Parameters:
    ///   - labelset: The labelset associated with this value.
    /// - Returns: The bound counter metric.
    func bind(labelset: LabelSet) -> BoundRawCounterMetric<T>

    /// Gets the bound counter metric with given labels.
    /// - Parameters:
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound counter metric.
    func bind(labels: [String: String]) -> BoundRawCounterMetric<T>
}


public struct AnyRawCounterMetric<T> :RawCounterMetric {
    
    let internalCounter : Any
    private let _recordLabels: (T, Date, Date, [String:String]) -> Void
    private let _recordLabelset: (T, Date, Date, LabelSet) -> Void
    private let _bindLabels: ([String:String]) -> BoundRawCounterMetric<T>
    private let _bindLabelset: (LabelSet) -> BoundRawCounterMetric<T>

    public init<U: RawCounterMetric>(_ countable: U) where U.T == T {
        internalCounter = countable
        _recordLabels = countable.record(sum:startDate:endDate:labels:)
        _recordLabelset = countable.record(sum:startDate:endDate:labelset:)
        _bindLabels = countable.bind(labels:)
        _bindLabelset = countable.bind(labelset:)
    }
    
    public func bind(labelset: LabelSet) -> BoundRawCounterMetric<T> {
        _bindLabelset(labelset)
    }
    
    public func bind(labels: [String : String]) -> BoundRawCounterMetric<T> {
        _bindLabels(labels)
    }
    
    public func record(sum: T, startDate: Date, endDate: Date, labelset: LabelSet) {
        _recordLabelset(sum, startDate, endDate, labelset)
    }
    
    public func record(sum: T, startDate: Date, endDate: Date, labels:[String:String]) {
        _recordLabels(sum, startDate, endDate, labels)
    }
   
    
}

public struct NoopRawCounterMetric<T> : RawCounterMetric {
    public func record(sum: T, startDate: Date, endDate: Date, labels: [String : String]) {}
    
    public func record(sum: T, startDate: Date, endDate: Date, labelset: LabelSet) {}
    
    public func bind(labelset: LabelSet) -> BoundRawCounterMetric<T> {
        BoundRawCounterMetric<T>()
    }
    
    public func bind(labels: [String : String]) -> BoundRawCounterMetric<T> {
        BoundRawCounterMetric<T>()
    }
}

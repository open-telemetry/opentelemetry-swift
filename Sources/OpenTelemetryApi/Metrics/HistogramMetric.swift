/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Measure instrument.
public protocol HistogramMetric {
    associatedtype T
    /// Gets the bound histogram metric with given labelset.
    /// - Parameters:
    ///   - labelset: The labelset from which bound instrument should be constructed.
    /// - Returns: The bound histogram metric.

    func bind(labelset: LabelSet) -> BoundHistogramMetric<T>

    /// Gets the bound histogram metric with given labelset.
    /// - Parameters:
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound histogram metric.
    func bind(labels: [String: String]) -> BoundHistogramMetric<T>
}

public extension HistogramMetric {
    /// Records a histogram.
    /// - Parameters:
    ///   - value: value to record.
    ///   - labelset: The labelset associated with this value.
    func record(value: T, labelset: LabelSet) {
        bind(labelset: labelset).record(value: value)
    }

    /// Records a histogram.
    /// - Parameters:
    ///   - value: value to record.
    ///   - labels: The labels or dimensions associated with this value.
    func record(value: T, labels: [String: String]) {
        bind(labels: labels).record(value: value)
    }
}

public struct AnyHistogramMetric<T>: HistogramMetric {
    private let _bindLabelSet: (LabelSet) -> BoundHistogramMetric<T>
    private let _bindLabels: ([String: String]) -> BoundHistogramMetric<T>

    public init<U: HistogramMetric>(_ histogram: U) where U.T == T {
        _bindLabelSet = histogram.bind(labelset:)
        _bindLabels = histogram.bind(labels:)
    }

    public func bind(labelset: LabelSet) -> BoundHistogramMetric<T> {
        _bindLabelSet(labelset)
    }

    public func bind(labels: [String: String]) -> BoundHistogramMetric<T> {
        _bindLabels(labels)
    }
}

public struct NoopHistogramMetric<T>: HistogramMetric {
    public init() {}

    public func bind(labelset: LabelSet) -> BoundHistogramMetric<T> {
        BoundHistogramMetric<T>()
    }

    public func bind(labels: [String: String]) -> BoundHistogramMetric<T> {
        BoundHistogramMetric<T>()
    }
}

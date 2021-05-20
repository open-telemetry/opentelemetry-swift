/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Measure instrument.
public protocol MeasureMetric {
    associatedtype T
    /// Gets the bound measure metric with given labelset.
    /// - Parameters:
    ///   - labelset: The labelset from which bound instrument should be constructed.
    /// - Returns: The bound measure metric.

    func bind(labelset: LabelSet) -> BoundMeasureMetric<T>

    /// Gets the bound measure metric with given labelset.
    /// - Parameters:
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound measure metric.
    func bind(labels: [String: String]) -> BoundMeasureMetric<T>
}

public extension MeasureMetric {
    /// Records a measure.
    /// - Parameters:
    ///   - value: value to record.
    ///   - labelset: The labelset associated with this value.
    func record(value: T, labelset: LabelSet) {
        bind(labelset: labelset).record(value: value)
    }

    /// Records a measure.
    /// - Parameters:
    ///   - value: value to record.
    ///   - labels: The labels or dimensions associated with this value.
    func record(value: T, labels: [String: String]) {
        bind(labels: labels).record(value: value)
    }
}

public struct AnyMeasureMetric<T>: MeasureMetric {
    private let _bindLabelSet: (LabelSet) -> BoundMeasureMetric<T>
    private let _bindLabels: ([String: String]) -> BoundMeasureMetric<T>

    public init<U: MeasureMetric>(_ measurable: U) where U.T == T {
        _bindLabelSet = measurable.bind(labelset:)
        _bindLabels = measurable.bind(labels:)
    }

    public func bind(labelset: LabelSet) -> BoundMeasureMetric<T> {
        _bindLabelSet(labelset)
    }

    public func bind(labels: [String: String]) -> BoundMeasureMetric<T> {
        _bindLabels(labels)
    }
}

public struct NoopMeasureMetric<T>: MeasureMetric {
    public init() {}

    public func bind(labelset: LabelSet) -> BoundMeasureMetric<T> {
        BoundMeasureMetric<T>()
    }

    public func bind(labels: [String: String]) -> BoundMeasureMetric<T> {
        BoundMeasureMetric<T>()
    }
}

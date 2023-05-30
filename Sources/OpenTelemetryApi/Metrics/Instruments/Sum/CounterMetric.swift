/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Counter instrument.
// Phase 2
//@available(*,deprecated)
public protocol CounterMetric {
    associatedtype T

    /// Adds or Increments the counter.
    /// - Parameters:
    ///   - value: value by which the counter should be incremented.
    ///   - labelset: The labelset associated with this value.
    func add(value: T, labelset: LabelSet)

    /// Adds or Increments the counter.
    /// - Parameters:
    ///   - value: value by which the counter should be incremented.
    ///   - labels: The labels or dimensions associated with this value.
    func add(value: T, labels: [String: String])

    /// Gets the bound counter metric with given labelset.
    /// - Parameters:
    ///   - labelset: The labelset associated with this value.
    /// - Returns: The bound counter metric.
    func bind(labelset: LabelSet) -> BoundCounterMetric<T>

    /// Gets the bound counter metric with given labels.
    /// - Parameters:
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound counter metric.
    func bind(labels: [String: String]) -> BoundCounterMetric<T>
}
public struct AnyCounterMetric<T>: CounterMetric {
    let internalCounter: Any
    private let _addLabelSet: (T, LabelSet) -> Void
    private let _addLabels: (T, [String: String]) -> Void
    private let _bindLabelSet: (LabelSet) -> BoundCounterMetric<T>
    private let _bindLabels: ([String: String]) -> BoundCounterMetric<T>

    public init<U: CounterMetric>(_ countable: U) where U.T == T {
        internalCounter = countable
        _addLabelSet = countable.add(value:labelset:)
        _addLabels = countable.add(value:labels:)
        _bindLabelSet = countable.bind(labelset:)
        _bindLabels = countable.bind(labels:)
    }

    public func add(value: T, labelset: LabelSet) {
        _addLabelSet(value, labelset)
    }

    public func add(value: T, labels: [String: String]) {
        _addLabels(value, labels)
    }

    public func bind(labelset: LabelSet) -> BoundCounterMetric<T> {
        _bindLabelSet(labelset)
    }

    public func bind(labels: [String: String]) -> BoundCounterMetric<T> {
        _bindLabels(labels)
    }
}

public struct NoopCounterMetric<T>: CounterMetric {
    public init() {}

    public func add(value: T, labelset: LabelSet) {}

    public func add(value: T, labels: [String: String]) {}

    public func bind(labelset: LabelSet) -> BoundCounterMetric<T> {
        return BoundCounterMetric<T>()
    }

    public func bind(labels: [String: String]) -> BoundCounterMetric<T> {
        return BoundCounterMetric<T>()
    }
}

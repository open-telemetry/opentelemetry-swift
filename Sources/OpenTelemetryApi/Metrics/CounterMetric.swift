// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/// Counter instrument.
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

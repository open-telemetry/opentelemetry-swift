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

public protocol CounterMetric {
    associatedtype T

    func add(inContext: SpanContext, value: T, labelset: LabelSet)
    func add(inContext: SpanContext, value: T, labels: [String: String])
//    func add(inContext: DistributedContext,  value: T,  labelset: LabelSet)
//    func add(inContext: DistributedContext,  value: T, labels: [String: String])
    func bind(labelset: LabelSet) -> BoundCounterMetric<T>
    func bind(labels: [String: String]) -> BoundCounterMetric<T>
}

public struct AnyCounterMetric<T>: CounterMetric {
    let internalCounter: Any
    private let _addLabelSet: (SpanContext, T, LabelSet) -> Void
    private let _addLabels: (SpanContext, T, [String: String]) -> Void
    private let _bindLabelSet: (LabelSet) -> BoundCounterMetric<T>
    private let _bindLabels: ([String: String]) -> BoundCounterMetric<T>

    public init<U: CounterMetric>(_ countable: U) where U.T == T {
        internalCounter = countable
        _addLabelSet = countable.add(inContext:value:labelset:)
        _addLabels = countable.add(inContext:value:labels:)
        _bindLabelSet = countable.bind(labelset:)
        _bindLabels = countable.bind(labels:)
    }

    public func add(inContext: SpanContext, value: T, labelset: LabelSet) {
        _addLabelSet(inContext, value, labelset)
    }

    public func add(inContext: SpanContext, value: T, labels: [String: String]) {
        _addLabels(inContext, value, labels)
    }

    public func bind(labelset: LabelSet) -> BoundCounterMetric<T> {
        _bindLabelSet(labelset)
    }

    public func bind(labels: [String: String]) -> BoundCounterMetric<T> {
        _bindLabels(labels)
    }
}

struct NoopCounterMetric<T>: CounterMetric {
    func add(inContext: SpanContext, value: T, labelset: LabelSet) {
    }

    func add(inContext: SpanContext, value: T, labels: [String: String]) {
    }

    func bind(labelset: LabelSet) -> BoundCounterMetric<T> {
        return BoundCounterMetric<T>()
    }

    func bind(labels: [String: String]) -> BoundCounterMetric<T> {
        return BoundCounterMetric<T>()
    }
}

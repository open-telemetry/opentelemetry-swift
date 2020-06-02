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

public protocol MeasureMetric {
    associatedtype T
    func bind(labelset: LabelSet) -> BoundMeasureMetric<T>
    func bind(labels: [String: String]) -> BoundMeasureMetric<T>
}

public extension MeasureMetric {
    func record(value: T, labelset: LabelSet) {
        bind(labelset: labelset).record(value: value)
    }

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

struct NoopMeasureMetric<T>: MeasureMetric {
    func bind(labelset: LabelSet) -> BoundMeasureMetric<T> {
        BoundMeasureMetric<T>()
    }

    func bind(labels: [String: String]) -> BoundMeasureMetric<T> {
        BoundMeasureMetric<T>()
    }
}

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

public protocol Meter {
    mutating func createIntCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Int>
    mutating func createDoubleCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Double>
    mutating func createIntMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Int>
    mutating func createDoubleMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Double>
    mutating func createIntObserver(name: String, absolute: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric
    mutating func createDoubleObserver(name: String, absolute: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric
    var labelSet: LabelSet { get }
}

extension Meter {
    mutating func createIntCounter(name: String) -> AnyCounterMetric<Int> {
        return createIntCounter(name: name, monotonic: true)
    }

    mutating func createDoubleCounter(name: String) -> AnyCounterMetric<Double> {
        return createDoubleCounter(name: name, monotonic: true)
    }

    mutating func createIntMeasure(name: String) -> AnyMeasureMetric<Int> {
        return createIntMeasure(name: name, absolute: true)
    }

    mutating func createDoubleMeasure(name: String) -> AnyMeasureMetric<Double> {
        return createDoubleMeasure(name: name, absolute: true)
    }

    mutating func createIntObserver(name: String, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return createIntObserver(name: name, absolute: true, callback: callback)
    }

    mutating func createDoubleObserver(name: String, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return createDoubleObserver(name: name, absolute: true, callback: callback)
    }
}

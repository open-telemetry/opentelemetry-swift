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

public protocol Meter: AnyObject {
    func createIntCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Int>
    func createDoubleCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Double>
    func createIntMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Int>
    func createDoubleMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Double>
    func createIntObserver(name: String, absolute: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric
    func createDoubleObserver(name: String, absolute: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric
    func getLabelSet(labels: [String: String]) -> LabelSet
}

public extension Meter {
    func createIntCounter(name: String) -> AnyCounterMetric<Int> {
        return createIntCounter(name: name, monotonic: true)
    }

    func createDoubleCounter(name: String) -> AnyCounterMetric<Double> {
        return createDoubleCounter(name: name, monotonic: true)
    }

    func createIntMeasure(name: String) -> AnyMeasureMetric<Int> {
        return createIntMeasure(name: name, absolute: true)
    }

    func createDoubleMeasure(name: String) -> AnyMeasureMetric<Double> {
        return createDoubleMeasure(name: name, absolute: true)
    }

    func createIntObserver(name: String, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return createIntObserver(name: name, absolute: true, callback: callback)
    }

    func createDoubleObserver(name: String, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return createDoubleObserver(name: name, absolute: true, callback: callback)
    }
}

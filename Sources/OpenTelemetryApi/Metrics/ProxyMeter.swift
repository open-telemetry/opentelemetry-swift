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

/// Proxy Meter which act as a No-Op Meter, until real meter is provided.
public struct ProxyMeter: Meter {
    private var realMeter: Meter?

    public func getLabelSet(labels: [String: String]) -> LabelSet {
        return realMeter?.getLabelSet(labels: labels) ?? LabelSet.empty
    }

    public func createIntCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Int> {
        return realMeter?.createIntCounter(name: name, monotonic: monotonic) ?? AnyCounterMetric<Int>(NoopCounterMetric<Int>())
    }

    public func createDoubleCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Double> {
        return realMeter?.createDoubleCounter(name: name, monotonic: monotonic) ?? AnyCounterMetric<Double>(NoopCounterMetric<Double>())
    }

    public func createIntMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Int> {
        return realMeter?.createIntMeasure(name: name, absolute: absolute) ?? AnyMeasureMetric<Int>(NoopMeasureMetric<Int>())
    }

    public func createDoubleMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Double> {
        return realMeter?.createDoubleMeasure(name: name, absolute: absolute) ?? AnyMeasureMetric<Double>(NoopMeasureMetric<Double>())
    }

    public func createIntObserver(name: String, absolute: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return realMeter?.createIntObserver(name: name, absolute: absolute, callback: callback) ?? NoopIntObserverMetric()
    }

    public func createDoubleObserver(name: String, absolute: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return realMeter?.createDoubleObserver(name: name, absolute: absolute, callback: callback) ?? NoopDoubleObserverMetric()
    }

    mutating func updateMeter(realMeter: Meter) {
        guard self.realMeter == nil else {
            return
        }
        self.realMeter = realMeter
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Proxy Meter which act as a No-Op Meter, until real meter is provided.
public struct ProxyMeter: Meter {

    public func createRawDoubleCounter(name: String) -> AnyRawCounterMetric<Double> {
        return realMeter?.createRawDoubleCounter(name: name) ?? AnyRawCounterMetric<Double>(NoopRawCounterMetric<Double>())
    }
    
    
    public func createRawIntCounter(name: String) -> AnyRawCounterMetric<Int> {
        return realMeter?.createRawIntCounter(name: name) ?? AnyRawCounterMetric<Int>(NoopRawCounterMetric<Int>())
    }
    
    public func createRawDoubleHistogram(name: String) -> AnyRawHistogramMetric<Double> {
        return realMeter?.createRawDoubleHistogram(name: name) ?? AnyRawHistogramMetric<Double>(NoopRawHistogramMetric<Double>())
    }
    
    public func createRawIntHistogram(name: String) -> AnyRawHistogramMetric<Int> {
        return realMeter?.createRawIntHistogram(name: name) ?? AnyRawHistogramMetric<Int>(NoopRawHistogramMetric<Int>())
    }
    
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
    
    public func createIntHistogram(name: String, explicitBoundaries: Array<Int>? = nil, absolute: Bool) -> AnyHistogramMetric<Int> {
        return realMeter?.createIntHistogram(name: name, explicitBoundaries: explicitBoundaries, absolute: absolute) ?? AnyHistogramMetric<Int>(NoopHistogramMetric<Int>())
    }
    
    public func createDoubleHistogram(name: String, explicitBoundaries: Array<Double>?, absolute: Bool) -> AnyHistogramMetric<Double> {
        return realMeter?.createDoubleHistogram(name: name, explicitBoundaries: explicitBoundaries, absolute: absolute) ?? AnyHistogramMetric<Double>(NoopHistogramMetric<Double>())
    }

    public func createIntObservableGauge(name: String, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return realMeter?.createIntObservableGauge(name: name, callback: callback) ?? NoopIntObserverMetric()
    }

    public func createDoubleObservableGauge(name: String, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return realMeter?.createDoubleObservableGauge(name: name, callback: callback) ?? NoopDoubleObserverMetric()
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

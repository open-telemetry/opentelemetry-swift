/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Main interface to obtain metric instruments.
public protocol Meter {
    /// Creates Int counter with given name.
    /// - Parameters:
    ///   - name: The name of the counter.
    ///   - monotonic: indicates if only positive values are expected.
    /// - Returns:The counter instance.
    func createIntCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Int>

    /// Creates double counter with given name.
    /// - Parameters:
    ///   - name: indicates if only positive values are expected.
    ///   - monotonic: The name of the counter.
    /// - Returns:The counter instance.
    func createDoubleCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Double>

    /// Creates Int Measure with given name.
    /// - Parameters:
    ///   - name: The name of the measure.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The measure instance.
    func createIntMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Int>

    /// Creates double Measure with given name.
    /// - Parameters:
    ///   - name: The name of the measure.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The measure instance.
    func createDoubleMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Double>

    /// Creates Int Observer with given name.
    /// - Parameters:
    ///   - name: The name of the observer.
    ///   - callback: The callback to be called to observe metric value.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The observer instance.
    func createIntObserver(name: String, absolute: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric

    /// Creates Double Observer with given name.
    /// - Parameters:
    ///   - name: The name of the observer.
    ///   - callback: The callback to be called to observe metric value.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The observer instance.
    func createDoubleObserver(name: String, absolute: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric

    /// Creates Double Observable Gauge with given name.
    /// - Parameters:
    ///   - name: The name of the gauge.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:The gauge instance.
    func createIntObservableGauge(name: String, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric

    /// Creates Int Observable Gauge with given name.
    /// - Parameters:
    ///   - name: The name of the gauge.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:The gauge instance.
    func createDoubleObservableGauge(name: String, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric

    /// Constructs or retrieves the LabelSet from the given dictionary.
    /// - Parameters:
    ///   - labels: dictionary with  key-value pairs.
    /// - Returns:The LabelSet with given label key value pairs.
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

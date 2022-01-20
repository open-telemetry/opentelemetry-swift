/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Main interface to obtain metric instruments.
///
///
@available(*, deprecated, renamed: "StableMeter")
public protocol Meter {

    /// Creates Int counter with given name.
    /// - Parameters:
    ///   - name: The name of the counter.
    ///   - monotonic: indicates if only positive values are expected.
    /// - Returns:The counter instance.
    @available(*,deprecated, message: "counter instruments are now monotonic only. Use UpDownCounter for non-monotonic.")
    func createIntCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Int>

    /// Creates double counter with given name.
    /// - Parameters:
    ///   - name: indicates if only positive values are expected.
    ///   - monotonic: The name of the counter.
    /// - Returns:The counter instance.
    @available(*,deprecated, message: "counter instruments are now monotonic only. Use UpDownCounter for non-monotonic.")
    func createDoubleCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Double>

    /// Creates Int Measure with given name.
    /// - Parameters:
    ///   - name: The name of the measure.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The measure instance.
    @available(*,deprecated)
    func createIntMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Int>

    /// Creates double Measure with given name.
    /// - Parameters:
    ///   - name: The name of the measure.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The measure instance.
    @available(*,deprecated)
    func createDoubleMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Double>
    
    /// Creates Int Histogram with given name and boundaries.
    /// - Parameters:
    ///   - name: The name of the measure.
    ///   - explicitBoundaries: The boundary for sorting values into buckets
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The histogram instance.
    @available(*,deprecated)
    func createIntHistogram(name: String, explicitBoundaries: Array<Int>?, absolute: Bool) -> AnyHistogramMetric<Int>
    
    /// Creates Double Histogram with given name and boundaries.
    /// - Parameters:
    ///   - name: The name of the measure.
    ///   - explicitBoundaries: The boundary for sorting values into buckets
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The histogram instance.
    @available(*,deprecated)
    func createDoubleHistogram(name: String, explicitBoundaries: Array<Double>?, absolute: Bool) -> AnyHistogramMetric<Double>

    /// Creates Int Observer with given name.
    /// - Parameters:
    ///   - name: The name of the observer.
    ///   - callback: The callback to be called to observe metric value.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The observer instance.
    @available(*,deprecated)
    func createIntObserver(name: String, absolute: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric

    /// Creates Double Observer with given name.
    /// - Parameters:
    ///   - name: The name of the observer.
    ///   - callback: The callback to be called to observe metric value.
    ///   - absolute: indicates if only positive values are expected.
    /// - Returns:The observer instance.
    @available(*,deprecated)
    func createDoubleObserver(name: String, absolute: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric

    /// Creates Double Observable Gauge with given name.
    /// - Parameters:
    ///   - name: The name of the gauge.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:The gauge instance.
    @available(*,deprecated)
    func createIntObservableGauge(name: String, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric

    /// Creates Int Observable Gauge with given name.
    /// - Parameters:
    ///   - name: The name of the gauge.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:The gauge instance.
    @available(*,deprecated)
    func createDoubleObservableGauge(name: String, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric

    /// Constructs or retrieves the LabelSet from the given dictionary.
    /// - Parameters:
    ///   - labels: dictionary with  key-value pairs.
    /// - Returns:The LabelSet with given label key value pairs.
    @available(*,deprecated, message: "removed from metrics spec in OTEP-90")
    func getLabelSet(labels: [String: String]) -> LabelSet
}

public extension Meter {
    @available(*,deprecated)
    func createIntCounter(name: String) -> AnyCounterMetric<Int> {
        return createIntCounter(name: name, monotonic: true)
    }

    @available(*,deprecated)
    func createDoubleCounter(name: String) -> AnyCounterMetric<Double> {
        return createDoubleCounter(name: name, monotonic: true)
    }

    @available(*,deprecated)
    func createIntMeasure(name: String) -> AnyMeasureMetric<Int> {
        return createIntMeasure(name: name, absolute: true)
    }

    @available(*,deprecated)
    func createDoubleMeasure(name: String) -> AnyMeasureMetric<Double> {
        return createDoubleMeasure(name: name, absolute: true)
    }

    @available(*,deprecated)
    func createIntObserver(name: String, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return createIntObserver(name: name, absolute: true, callback: callback)
    }

    @available(*,deprecated)
    func createDoubleObserver(name: String, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return createDoubleObserver(name: name, absolute: true, callback: callback)
    }
}

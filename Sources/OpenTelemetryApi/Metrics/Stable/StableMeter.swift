/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Main interface to obtain metric instruments.
/// Replaces Meter class. After a deprecation period StableMeter will be renamed to Meter
///
public protocol StableMeter {
    /// Create a new Int counter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    /// - Returns: An AnyCounterMetric<Int> instrument
    func createIntCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Int>

    /// Create a new Double counter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    /// - Returns: An AnyCounterMetric<Double> instrument
    func createDoubleCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Double>

    /// create a new Asynchronous Int counter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns: IntObserverMetric
    func createIntObservableCounter(name: String, unit: String?, description: String?, callback: @escaping (IntObserverMetric)-> Void) -> IntObserverMetric

    /// create a new Asynchronous double counter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:
    func createDoubleObservableCounter(name: String, unit: String?, description: String?, callback: @escaping (DoubleObserverMetric)-> Void) -> DoubleObserverMetric

    /// create a new Int histogram
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    /// - Returns:
    func createIntHistogram(name: String, unit: String?, description: String?) -> AnyHistogramMetric<Int>

    /// create a new Double histogram
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    /// - Returns:
    func createDoubleHistogram(name: String, unit:String?, description: String?) -> AnyHistogramMetric<Double>

    /// create a new Asynchronous Int gauge
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:
    func createIntObservableGauge(name: String, unit: String?, description: String?, callback: @escaping(DoubleObserverMetric)->Void) -> DoubleObserverMetric

    /// create a new Asynchronous Double gauge
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:
    func createDoubleObservableGauge(name: String, unit: String?, description: String?, callback: @escaping(IntObserverMetric)->Void) -> IntObserverMetric

    /// create a new Int UpDownCounter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    /// - Returns:
    func createIntUpDownCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Int>

    /// create a new Double UpDownCounter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    /// - Returns:
    func createDoubleUpDownCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Double>

    /// create a new Asynchronous Int UpDownCounter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:
    func createObservableIntUpDownCounter(name: String, unit: String?, description: String?, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric

    /// create a new Asynchronous Double UpDownCounter
    ///
    /// - Parameters:
    ///   - name: The name of the instrument.
    ///   - unit: An optional unit of measurement.
    ///   - description: An optional free-form description of the instrument.
    ///   - callback: The callback to be called to observe metric value.
    /// - Returns:
    func createObservableDoubleUpDownCounter(name: String, unit: String?, description: String?, callback: @escaping(DoubleObserverMetric)-> Void ) -> DoubleObserverMetric

}



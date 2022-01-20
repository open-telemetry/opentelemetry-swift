/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
class StableMeterSdk : StableMeter {
    fileprivate let collectLock = Lock()
    var instrumentationLibraryInfo: InstrumentationLibraryInfo

    var intCounters = [String: IntCounterSdk]()
    var doubleCounters = [String: DoubleCounterSdk]()
    var intObservableCounters = [String: IntObservableCounterSdk]()
    var doubleObservableCounter = [String: DoubleObservableCounterSdk]()

    // stub: maybe this doesn't throw, nor return metric data
    func collect() throws -> MetricData {
        return NoopMetricData()
    }

    init(instrumentationLibraryInfo: InstrumentationLibraryInfo) {
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
    }

    func createIntCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Int> {
        fatalError("createIntCounter(name:unit:description:) has not been implemented")
    }

    func createDoubleCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Double> {
        fatalError("createDoubleCounter(name:unit:description:) has not been implemented")
    }

    func createIntObservableCounter(name: String, unit: String?, description: String?, callback: @escaping (IntObserverMetric) -> ()) -> IntObserverMetric {
        fatalError("createIntObservableCounter(name:unit:description:callback:) has not been implemented")
    }

    func createDoubleObservableCounter(name: String, unit: String?, description: String?, callback: @escaping (DoubleObserverMetric) -> ()) -> DoubleObserverMetric {
        fatalError("createDoubleObservableCounter(name:unit:description:callback:) has not been implemented")
    }

    func createIntHistogram(name: String, unit: String?, description: String?) -> AnyHistogramMetric<Int> {
        fatalError("createIntHistogram(name:unit:description:) has not been implemented")
    }

    func createDoubleHistogram(name: String, unit: String?, description: String?) -> AnyHistogramMetric<Double> {
        fatalError("createDoubleHistogram(name:unit:description:) has not been implemented")
    }

    func createIntObservableGauge(name: String, unit: String?, description: String?, callback: @escaping (DoubleObserverMetric) -> ()) -> DoubleObserverMetric {
        fatalError("createIntObservableGauge(name:unit:description:callback:) has not been implemented")
    }

    func createDoubleObservableGauge(name: String, unit: String?, description: String?, callback: @escaping (IntObserverMetric) -> ()) -> IntObserverMetric {
        fatalError("createDoubleObservableGauge(name:unit:description:callback:) has not been implemented")
    }

    func createIntUpDownCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Int> {
        fatalError("createIntUpDownCounter(name:unit:description:) has not been implemented")
    }

    func createDoubleUpDownCounter(name: String, unit: String?, description: String?) -> AnyCounterMetric<Double> {
        fatalError("createDoubleUpDownCounter(name:unit:description:) has not been implemented")
    }

    func createObservableIntUpDownCounter(name: String, unit: String?, description: String?, callback: @escaping (IntObserverMetric) -> ()) -> IntObserverMetric {
        fatalError("createObservableIntUpDownCounter(name:unit:description:callback:) has not been implemented")
    }

    func createObservableDoubleUpDownCounter(name: String, unit: String?, description: String?, callback: @escaping (DoubleObserverMetric) -> ()) -> DoubleObserverMetric {
        fatalError("createObservableDoubleUpDownCounter(name:unit:description:callback:) has not been implemented")
    }
}

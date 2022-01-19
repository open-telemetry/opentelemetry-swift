//
// Created by Bryce Buchanan on 1/19/22.
//

import Foundation
import OpenTelemetryApi
class StableMeterSdk : StableMeter {
    fileprivate let collectLock = Lock()
    var instrumentationLibraryInfo: InstrumentationLibraryInfo
    var meterSharedState : StableMeterSharedState

    var intCounters = [String: CounterMetricSdk<Int>]()
    var doubleCounters = [String: CounterMetricSdk<Double>]()
    var intObservableCounters = [String: IntObserverMetric]()

    init(meterSharedState: StableMeterSharedState, instrumentationLibraryInfo: InstrumentationLibraryInfo) {
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.meterSharedState = meterSharedState
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

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public extension Meter {
    func addMetric(name: String, type: AggregationType, data: [MetricData]) {
        //noop
    }
}

class MeterSdk: Meter {


    
    fileprivate let collectLock = Lock()
    fileprivate let rawMetricLock = Lock()
    let meterName: String
    var metricProcessor: MetricProcessor
    var instrumentationScopeInfo: InstrumentationScopeInfo
    var resource: Resource

    var intGauges = [String: IntObservableGaugeSdk]()
    var doubleGauges = [String: DoubleObservableGaugeSdk]()
    var intCounters = [String: CounterMetricSdk<Int>]()
    var doubleCounters = [String: CounterMetricSdk<Double>]()
    var intMeasures = [String: MeasureMetricSdk<Int>]()
    var doubleMeasures = [String: MeasureMetricSdk<Double>]()
    var intHistogram = [String: HistogramMetricSdk<Int>]()
    var rawDoubleHistogram = [String: RawHistogramMetricSdk<Double>]()
    var rawIntHistogram = [String: RawHistogramMetricSdk<Int>]()
    var rawDoubleCounters = [String: RawCounterMetricSdk<Double>]()
    var rawIntCounters = [String: RawCounterMetricSdk<Int>]()
    var doubleHistogram = [String: HistogramMetricSdk<Double>]()
    var intObservers = [String: IntObserverMetricSdk]()
    var doubleObservers = [String: DoubleObserverMetricSdk]()

    var metrics = [Metric]()
    
    init(meterSharedState: MeterSharedState, instrumentationScopeInfo: InstrumentationScopeInfo) {
        meterName = instrumentationScopeInfo.name
        resource = meterSharedState.resource
        metricProcessor = meterSharedState.metricProcessor
        self.instrumentationScopeInfo = instrumentationScopeInfo
    }

    func getLabelSet(labels: [String: String]) -> LabelSet {
        return LabelSetSdk(labels: labels)
    }

    func addMetric(name: String, type: AggregationType, data: [MetricData]) {
        var metric = Metric(namespace: meterName, name: name, desc: meterName + name, type: type, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
        metric.data = data
        rawMetricLock.withLockVoid {
            metrics.append(metric)
        }
    }
    
    func collect() {
        collectLock.withLockVoid {
            var boundInstrumentsToRemove = [LabelSet]()


            // process raw metrics
            var checkpointMetrics = [Metric]()
            rawMetricLock.withLockVoid {
               checkpointMetrics = metrics
                metrics = [Metric]()
            }
            checkpointMetrics.forEach {
                metricProcessor.process(metric: $0)
            }
            
            intCounters.forEach { counter in
                let metricName = counter.key
                let counterInstrument = counter.value

                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.intSum, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)

                counterInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()

                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }

                metricProcessor.process(metric: metric)
                boundInstrumentsToRemove.forEach { boundInstrument in
                    counterInstrument.unBind(labelSet: boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
            }

            doubleCounters.forEach { counter in
                let metricName = counter.key
                let counterInstrument = counter.value

                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.doubleSum, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)

                counterInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()

                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)

                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }

                metricProcessor.process(metric: metric)
                boundInstrumentsToRemove.forEach { boundInstrument in
                    counterInstrument.unBind(labelSet: boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
            }

            intMeasures.forEach { measure in
                let metricName = measure.key
                let measureInstrument = measure.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.intSummary, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                measureInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }

            doubleMeasures.forEach { measure in
                let metricName = measure.key
                let measureInstrument = measure.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.doubleSummary, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                measureInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }
            
            intHistogram.forEach { histogram in
                let metricName = histogram.key
                let measureInstrument = histogram.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.intHistogram, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                measureInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }
            
            doubleHistogram.forEach { histogram in
                let metricName = histogram.key
                let measureInstrument = histogram.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.doubleHistogram, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                measureInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }

            intGauges.forEach { gauge in
                let metricName = gauge.key
                let gaugeInstrument = gauge.value

                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: .intGauge, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)

                gaugeInstrument.invokeCallback()

                gaugeInstrument.observerHandles.forEach { handle in
                    let labelSet = handle.key
                    let aggregator = handle.value.aggregator
                    aggregator.checkpoint()

                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }

            doubleGauges.forEach { gauge in
                let metricName = gauge.key
                let gaugeInstrument = gauge.value

                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: .doubleGauge, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)

                gaugeInstrument.invokeCallback()

                gaugeInstrument.observerHandles.forEach { handle in
                    let labelSet = handle.key
                    let aggregator = handle.value.aggregator
                    aggregator.checkpoint()

                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }

            intObservers.forEach { observer in
                let metricName = observer.key
                let observerInstrument = observer.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.intSum, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                observerInstrument.invokeCallback()

                observerInstrument.observerHandles.forEach { handle in
                    let labelSet = handle.key
                    let aggregator = handle.value.aggregator
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }


            
            rawDoubleHistogram.forEach {
                histogram in
                    let name = histogram.key
                    let instrument = histogram.value
                
                    var metric = Metric(namespace: meterName, name: name, desc: meterName + name, type: .doubleHistogram, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                
                instrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let counter = boundInstrument.value
                    
                    counter.checkpoint()
                    var metricData = counter.getMetrics()
                    for (index, _) in metricData.enumerated() {
                            metricData[index].labels = labelSet.labels
                    }
                    
                    metric.data.append(contentsOf: metricData)
                    
                    
    
                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }
                metricProcessor.process(metric: metric)

                boundInstrumentsToRemove.forEach { boundInstrument in
                    instrument.unBind(labelSet:boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
            }
            
            rawIntHistogram.forEach { histogram in
                let name = histogram.key
                let instrument = histogram.value
                var metric = Metric(namespace: meterName, name: name, desc: meterName + name, type: .intHistogram, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
        
                instrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let counter = boundInstrument.value
                    
                    counter.checkpoint()
                    var metricData = counter.getMetrics()
                    for (index, _) in metricData.enumerated() {
                            metricData[index].labels = labelSet.labels
                    }
                    
                    metric.data.append(contentsOf: metricData)
                    
                    
    
                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }
                metricProcessor.process(metric: metric)

                boundInstrumentsToRemove.forEach { boundInstrument in
                    instrument.unBind(labelSet:boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
                
            }
            
            rawIntCounters.forEach {
                counter in
                let name = counter.key
                let instrument = counter.value
                
                var metric = Metric(namespace: meterName, name: name, desc: meterName + name, type: .intSum, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                
                instrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let counter = boundInstrument.value
                    
                    counter.checkpoint()
                    var metricData = counter.getMetrics()
                    for (index, _) in metricData.enumerated() {
                            metricData[index].labels = labelSet.labels
                    }
                    
                    metric.data.append(contentsOf: metricData)
                    
                    
    
                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }
                metricProcessor.process(metric: metric)

                boundInstrumentsToRemove.forEach { boundInstrument in
                    instrument.unBind(labelSet:boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
            }

            rawDoubleCounters.forEach {
                counter in
                let name = counter.key
                let instrument = counter.value
                
                var metric = Metric(namespace: meterName, name: name, desc: meterName + name, type: .intSum, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                
                instrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let counter = boundInstrument.value
                    
                    counter.checkpoint()
                    var metricData = counter.getMetrics()
                    for (index, _) in metricData.enumerated() {
                            metricData[index].labels = labelSet.labels
                    }
                    
                    metric.data.append(contentsOf: metricData)
                    
                    
    
                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }
                metricProcessor.process(metric: metric)

                boundInstrumentsToRemove.forEach { boundInstrument in
                    instrument.unBind(labelSet:boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
            }
            
            doubleObservers.forEach { observer in
                let metricName = observer.key
                let observerInstrument = observer.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.doubleSum, resource: resource, instrumentationScopeInfo: instrumentationScopeInfo)
                observerInstrument.invokeCallback()

                observerInstrument.observerHandles.forEach { handle in
                    let labelSet = handle.key
                    let aggregator = handle.value.aggregator
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }

                metricProcessor.process(metric: metric)
            }
        }
    }

    func createIntObservableGauge(name: String, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        var gauge = intGauges[name]
        if gauge == nil {
            gauge = IntObservableGaugeSdk(measurementName: name, callback: callback)
            collectLock.withLockVoid {
                intGauges[name] = gauge!
            }
        }
        return gauge!
    }

    func createDoubleObservableGauge(name: String, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        var gauge = doubleGauges[name]
        if gauge == nil {
            gauge = DoubleObservableGaugeSdk(measurementName: name, callback: callback)
            collectLock.withLockVoid {
                doubleGauges[name] = gauge!
            }
        }
        return gauge!
    }

    func createIntCounter(name: String, monotonic _: Bool) -> AnyCounterMetric<Int> {
        var counter = intCounters[name]
        if counter == nil {
            counter = CounterMetricSdk<Int>(name: name)
            collectLock.withLockVoid {
                intCounters[name] = counter!
            }
        }
        return AnyCounterMetric<Int>(counter!)
    }

    func createDoubleCounter(name: String, monotonic _: Bool) -> AnyCounterMetric<Double> {
        var counter = doubleCounters[name]
        if counter == nil {
            counter = CounterMetricSdk<Double>(name: name)
            collectLock.withLockVoid {
                doubleCounters[name] = counter!
            }
        }
        return AnyCounterMetric<Double>(counter!)
    }

    func createIntMeasure(name: String, absolute _: Bool) -> AnyMeasureMetric<Int> {
        var measure = intMeasures[name]
        if measure == nil {
            measure = MeasureMetricSdk<Int>(name: name)
            collectLock.withLockVoid {
                intMeasures[name] = measure!
            }
        }
        return AnyMeasureMetric<Int>(measure!)
    }

    func createDoubleMeasure(name: String, absolute _: Bool) -> AnyMeasureMetric<Double> {
        var measure = doubleMeasures[name]
        if measure == nil {
            measure = MeasureMetricSdk<Double>(name: name)
            collectLock.withLockVoid {
                doubleMeasures[name] = measure
            }
        }
        return AnyMeasureMetric<Double>(measure!)
    }
    
    func createRawDoubleCounter(name: String) -> AnyRawCounterMetric<Double> {
        var measure = rawDoubleCounters[name]
        if measure == nil {
            measure = RawCounterMetricSdk<Double>(name: name)
            
            collectLock.withLockVoid {
                rawDoubleCounters[name] = measure!
            }
        }
        return AnyRawCounterMetric<Double>(measure!)
    }
    
    func createRawIntCounter(name: String) -> AnyRawCounterMetric<Int> {
        var measure = rawIntCounters[name]
        if measure == nil {
            measure = RawCounterMetricSdk<Int>(name: name)
            
            collectLock.withLockVoid {
                rawIntCounters[name] = measure!
            }
        }
        return AnyRawCounterMetric<Int>(measure!)
    }
    
    
    func createRawDoubleHistogram(name: String) -> AnyRawHistogramMetric<Double> {
        var histogram = rawDoubleHistogram[name]
        if histogram == nil {
            histogram = RawHistogramMetricSdk<Double>(name: name)
        }
        collectLock.withLockVoid {
            rawDoubleHistogram[name] = histogram!
        }
        return AnyRawHistogramMetric<Double>(histogram!)
    }
    
    func createRawIntHistogram(name: String) -> AnyRawHistogramMetric<Int> {
        var histogram = rawIntHistogram[name]
        if histogram == nil {
            histogram = RawHistogramMetricSdk<Int>(name: name)
        }
        collectLock.withLockVoid {
            rawIntHistogram[name] = histogram!
        }
        return AnyRawHistogramMetric<Int>(histogram!)
    }
    
    
    
    func createIntHistogram(name: String, explicitBoundaries: Array<Int>? = nil, absolute: Bool) -> AnyHistogramMetric<Int> {
        var histogram = intHistogram[name]
        if histogram == nil {
            histogram = HistogramMetricSdk<Int>(name: name, explicitBoundaries: explicitBoundaries)
            collectLock.withLockVoid {
                intHistogram[name] = histogram!
            }
        }
        return AnyHistogramMetric<Int>(histogram!)
    }
    
    func createDoubleHistogram(name: String, explicitBoundaries: Array<Double>? = nil, absolute: Bool) -> AnyHistogramMetric<Double> {
        var histogram = doubleHistogram[name]
        if histogram == nil {
            histogram = HistogramMetricSdk<Double>(name: name, explicitBoundaries: explicitBoundaries)
            collectLock.withLockVoid {
                doubleHistogram[name] = histogram!
            }
        }
        return AnyHistogramMetric<Double>(histogram!)
    }
    

    func createIntObserver(name: String, absolute _: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        var observer = intObservers[name]
        if observer == nil {
            observer = IntObserverMetricSdk(metricName: name, callback: callback)
            collectLock.withLockVoid {
                intObservers[name] = observer!
            }
        }
        return observer!
    }

    func createDoubleObserver(name: String, absolute _: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        var observer = doubleObservers[name]
        if observer == nil {
            observer = DoubleObserverMetricSdk(metricName: name, callback: callback)
            collectLock.withLockVoid {
                doubleObservers[name] = observer!
            }
        }
        return observer!
    }
}

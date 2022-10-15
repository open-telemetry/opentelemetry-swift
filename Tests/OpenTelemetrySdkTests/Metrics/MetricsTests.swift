/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class MetricsTests: XCTestCase {
    func testCounterSendsAggregateToRegisteredProcessor() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        let testCounter = meter.createIntCounter(name: "testCounter")

        let labels1 = ["dim1": "value1"]
        let labels2 = ["dim1": "value2"]
        let labels3 = ["dim1": "value3"]

        testCounter.add(value: 100, labelset: meter.getLabelSet(labels: labels1))
        testCounter.add(value: 10, labelset: meter.getLabelSet(labels: labels1))

        let boundCounterLabel2 = testCounter.bind(labels: labels2)
        boundCounterLabel2.add(value: 200)

        testCounter.add(value: 200, labelset: meter.getLabelSet(labels: labels3))
        testCounter.add(value: 10, labelset: meter.getLabelSet(labels: labels3))

        meter.collect()

        XCTAssertEqual(testProcessor.metrics.count, 1)
        let metric = testProcessor.metrics[0]

        XCTAssertEqual("testCounter", metric.name)
        XCTAssertEqual("scope1", metric.namespace)

        // 3 time series, as 3 unique label sets.
        XCTAssertEqual(3, metric.data.count)

        var metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value1" })
        var metricInt = metricSeries as! SumData<Int>
        XCTAssertEqual(110, metricInt.sum)

        metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value2" })
        metricInt = metricSeries as! SumData<Int>
        XCTAssertEqual(200, metricInt.sum)

        metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value3" })
        metricInt = metricSeries as! SumData<Int>
        XCTAssertEqual(210, metricInt.sum)
    }

    func testMeasureSendsAggregateToRegisteredProcessor() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        let testMeasure = meter.createIntMeasure(name: "testMeasure")

        let labels1 = ["dim1": "value1"]
        let labels2 = ["dim1": "value2"]

        testMeasure.record(value: 100, labelset: meter.getLabelSet(labels: labels1))
        testMeasure.record(value: 10, labelset: meter.getLabelSet(labels: labels1))
        testMeasure.record(value: 1, labelset: meter.getLabelSet(labels: labels1))
        testMeasure.record(value: 200, labelset: meter.getLabelSet(labels: labels2))
        testMeasure.record(value: 20, labelset: meter.getLabelSet(labels: labels2))

        meter.collect()

        XCTAssertEqual(testProcessor.metrics.count, 1)
        let metric = testProcessor.metrics[0]
        XCTAssertEqual("testMeasure", metric.name)
        XCTAssertEqual("scope1", metric.namespace)

        // 2 time series, as 2 unique label sets.
        XCTAssertEqual(2, metric.data.count)

        var metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value1" })
        var metricSummary = metricSeries as! SummaryData<Int>
        XCTAssertEqual(111, metricSummary.sum)
        XCTAssertEqual(3, metricSummary.count)
        XCTAssertEqual(1, metricSummary.min)
        XCTAssertEqual(100, metricSummary.max)

        metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value2" })
        metricSummary = metricSeries as! SummaryData<Int>
        XCTAssertEqual(220, metricSummary.sum)
        XCTAssertEqual(2, metricSummary.count)
        XCTAssertEqual(20, metricSummary.min)
        XCTAssertEqual(200, metricSummary.max)
    }

    func testIntObserverSendsAggregateToRegisteredProcessor() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        _ = meter.createIntObserver(name: "testObserver", callback: callbackInt)

        meter.collect()

        XCTAssertEqual(testProcessor.metrics.count, 1)
        let metric = testProcessor.metrics[0]
        XCTAssertEqual("testObserver", metric.name)
        XCTAssertEqual("scope1", metric.namespace)

        // 2 time series, as 2 unique label sets.
        XCTAssertEqual(2, metric.data.count)

        var metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value1" })
        var metricInt = metricSeries as! SumData<Int>
        XCTAssertEqual(30, metricInt.sum)

        metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value2" })
        metricInt = metricSeries as! SumData<Int>
        XCTAssertEqual(300, metricInt.sum)
    }

    private func callbackInt(observerMetric: IntObserverMetric) {
        let labels1 = ["dim1": "value1"]
        let labels2 = ["dim1": "value2"]

        observerMetric.observe(value: 10, labels: labels1)
        observerMetric.observe(value: 20, labels: labels1)
        observerMetric.observe(value: 30, labels: labels1)

        observerMetric.observe(value: 100, labels: labels2)
        observerMetric.observe(value: 200, labels: labels2)
        observerMetric.observe(value: 300, labels: labels2)
    }


    func testDoubleObserverSendsAggregateToRegisteredProcessor() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        _ = meter.createDoubleObserver(name: "testObserver", callback: callbackDouble)

        meter.collect()

        XCTAssertEqual(testProcessor.metrics.count, 1)
        let metric = testProcessor.metrics[0]
        XCTAssertEqual("testObserver", metric.name)
        XCTAssertEqual("scope1", metric.namespace)

        // 2 time series, as 2 unique label sets.
        XCTAssertEqual(2, metric.data.count)

        var metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value1" })
        var metricDouble = metricSeries as! SumData<Double>
        XCTAssertEqual(30, metricDouble.sum)

        metricSeries = metric.data.first(where: { $0.labels["dim1"] == "value2" })
        metricDouble = metricSeries as! SumData<Double>
        XCTAssertEqual(300, metricDouble.sum)
    }

    private func callbackDouble(observerMetric: DoubleObserverMetric) {
        let labels1 = ["dim1": "value1"]
        let labels2 = ["dim1": "value2"]

        observerMetric.observe(value: 10, labels: labels1)
        observerMetric.observe(value: 20, labels: labels1)
        observerMetric.observe(value: 30, labels: labels1)

        observerMetric.observe(value: 100, labels: labels2)
        observerMetric.observe(value: 200, labels: labels2)
        observerMetric.observe(value: 300, labels: labels2)
    }
    
    func testRawIntCounter() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        _ = meter.createRawIntCounter(name: "testRaw")
        
        meter.collect()
        XCTAssertEqual(testProcessor.metrics.count, 1)

        let metric = testProcessor.metrics[0]
        XCTAssertEqual("testRaw", metric.name)
        XCTAssertEqual("scope1", metric.namespace)

        
        
    }
    
    func testRawDoubleCounter() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        _ = meter.createRawDoubleCounter(name: "testRaw")
        
        meter.collect()
        XCTAssertEqual(testProcessor.metrics.count, 1)

        let metric = testProcessor.metrics[0]
        XCTAssertEqual("testRaw", metric.name)
        XCTAssertEqual("scope1", metric.namespace)
    }
    
    func testRawDoubleHitsogram() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        _ = meter.createRawDoubleHistogram(name: "testRaw")
        
        meter.collect()
        XCTAssertEqual(testProcessor.metrics.count, 1)

        let metric = testProcessor.metrics[0]
        XCTAssertEqual("testRaw", metric.name)
        XCTAssertEqual("scope1", metric.namespace)
    }
    
    func testRawIntHitsogram() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        _ = meter.createRawIntHistogram(name: "testRaw")
        
        meter.collect()
        XCTAssertEqual(testProcessor.metrics.count, 1)

        let metric = testProcessor.metrics[0]
        XCTAssertEqual("testRaw", metric.name)
        XCTAssertEqual("scope1", metric.namespace)
    }
}

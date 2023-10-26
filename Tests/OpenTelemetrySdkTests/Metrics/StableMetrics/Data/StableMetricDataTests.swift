//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class StableMetricDataTests: XCTestCase {
    let resource = Resource(attributes: ["foo": AttributeValue("bar")])
    let instrumentationScopeInfo = InstrumentationScopeInfo(name: "test")
    let metricName = "name"
    let metricDescription = "description"
    let emptyPointData = [PointData]()
    let unit = "unit"

    func testStableMetricDataCreation() {
        let type = MetricDataType.Summary
        let data = StableMetricData.Data(aggregationTemporality: .delta, points: emptyPointData)

        let metricData = StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: metricName, description: metricDescription, unit: unit, type: type, isMonotonic: false, data: data)
		
        assertCommon(metricData)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data, data)
        XCTAssertEqual(metricData.data.aggregationTemporality, .delta)
        XCTAssertEqual(metricData.isMonotonic, false)
    }

    func testEmptyStableMetricData() {
        XCTAssertEqual(StableMetricData.empty, StableMetricData(resource: Resource.empty, instrumentationScopeInfo: InstrumentationScopeInfo(), name: "", description: "", unit: "", type: .Summary, isMonotonic: false, data: StableMetricData.Data(aggregationTemporality: .cumulative, points: [PointData]())))
    }

    func testCreateExponentialHistogram() {
        let type = MetricDataType.ExponentialHistogram
        let histogramData = StableExponentialHistogramData(aggregationTemporality: .delta, points: emptyPointData)

        let metricData = StableMetricData.createExponentialHistogram(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: metricName, description: metricDescription, unit: unit, data: histogramData)

        assertCommon(metricData)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data, histogramData)
        XCTAssertEqual(metricData.data.aggregationTemporality, .delta)
        XCTAssertEqual(metricData.isMonotonic, false)
    }

    func testCreateHistogram() {
        let type = MetricDataType.Histogram

        let boundaries = [Double]()
        let sum:Double = 0
        let min = Double.greatestFiniteMagnitude
        let max:Double = -1
        let count = 0
        let counts = Array(repeating: 0, count: boundaries.count + 1)

        let histogramPointData = HistogramPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [ExemplarData](), sum: sum, count: UInt64(count), min: min, max: max, boundaries: boundaries, counts: counts, hasMin: count > 0, hasMax: count > 0)

        let points = [histogramPointData]
        let histogramData = StableHistogramData(aggregationTemporality: .cumulative, points: points)
        let metricData = StableMetricData.createHistogram(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: metricName, description: metricDescription, unit: unit, data: histogramData)

        assertCommon(metricData)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data, histogramData)
        XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
        XCTAssertEqual(metricData.isMonotonic, false)

        XCTAssertFalse(metricData.isEmpty())

        let hpd = metricData.getHistogramData()
        XCTAssertNotNil(hpd)
        XCTAssertEqual(1, hpd.count)
    }

    func testCreateDoubleGuage() {
        let type = MetricDataType.DoubleGauge
        let d: Double = 22.22222

        let point:PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: d)
        let guageData = StableGaugeData(aggregationTemporality: .cumulative, points: [point])
        let metricData = StableMetricData.createDoubleGauge(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: metricName, description: metricDescription, unit: unit, data: guageData)

        assertCommon(metricData)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data.points.first, point)
        XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
        XCTAssertEqual(metricData.isMonotonic, false)
    }

    func testCreateDoubleSum() {
        let type = MetricDataType.DoubleSum
        let d: Double = 44.4444

        let point:PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: d)
        let sumData = StableSumData(aggregationTemporality: .cumulative, points: [point])
        let metricData = StableMetricData.createDoubleSum(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: metricName, description: metricDescription, unit: unit, isMonotonic: true, data: sumData)

        assertCommon(metricData)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data.points.first, point)
        XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
        XCTAssertEqual(metricData.isMonotonic, true)
    }

    func testCreateLongGuage() {
        let type = MetricDataType.LongGauge
        let point:PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 33)
        let guageData = StableGaugeData(aggregationTemporality: .cumulative, points: [point])

        let metricData = StableMetricData.createLongGauge(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: metricName, description: metricDescription, unit: unit, data: guageData)

        assertCommon(metricData)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data.points.first, point)
        XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
        XCTAssertEqual(metricData.isMonotonic, false)
    }

    func testCreateLongSum() {
        let type = MetricDataType.LongSum
        let point:PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 55)
        let sumData = StableSumData(aggregationTemporality: .cumulative, points: [point])

        let metricData = StableMetricData.createLongSum(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: metricName, description: metricDescription, unit: unit, isMonotonic: true, data: sumData)

        assertCommon(metricData)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data.points.first, point)
        XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
        XCTAssertEqual(metricData.isMonotonic, true)
    }




    func assertCommon(_ metricData: StableMetricData) {
        XCTAssertEqual(metricData.resource, resource)
        XCTAssertEqual(metricData.instrumentationScopeInfo, instrumentationScopeInfo)
        XCTAssertEqual(metricData.name, metricName)
        XCTAssertEqual(metricData.description, metricDescription)
        XCTAssertEqual(metricData.unit, unit)
    }
}

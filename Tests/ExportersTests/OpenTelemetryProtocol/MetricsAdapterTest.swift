//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetrySdk

final class MetricsAdapterTest: XCTestCase {
    let resource = Resource(attributes: ["foo": AttributeValue("bar")])
    let instrumentationScopeInfo = InstrumentationScopeInfo(name: "test")
    let unit = "unit"

    func testToProtoResourceMetricsWithLongGuage() throws {
        let pointValue = Int.random(in: 1...999)
        let point:PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
        let guageData = StableGaugeData(aggregationTemporality: .cumulative, points: [point])
        let metricData = StableMetricData.createLongGauge(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, data: guageData)

        let result = MetricsAdapter.toProtoMetric(stableMetric: metricData)
        guard let value = result?.gauge.dataPoints as? [Opentelemetry_Proto_Metrics_V1_NumberDataPoint] else {
            let actualType = type(of: result?.gauge.dataPoints)
            let errorMessage = "Got wrong type: \(actualType)"
            XCTFail(errorMessage)
            throw errorMessage
        }

        XCTAssertEqual(value.first?.asInt, Int64(pointValue))
    }

    func testToProtoResourceMetricsWithLongSum() throws {
        let pointValue = Int.random(in: 1...999)
        let point:PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
        let sumData = StableSumData(aggregationTemporality: .cumulative, points: [point])
        let metricData = StableMetricData.createLongSum(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, isMonotonic: true, data: sumData)

        let result = MetricsAdapter.toProtoMetric(stableMetric: metricData)
        guard let value = result?.sum.dataPoints as? [Opentelemetry_Proto_Metrics_V1_NumberDataPoint] else {
            let actualType = type(of: result?.gauge.dataPoints)
            let errorMessage = "Got wrong type: \(actualType)"
            XCTFail(errorMessage)
            throw errorMessage
        }

        XCTAssertEqual(value.first?.asInt, Int64(pointValue))
        XCTAssertEqual(result?.sum.isMonotonic, true)
    }

    func testToProtoResourceMetricsWithDoubleGuage() throws {
        let pointValue: Double = Double.random(in: 1...999)
        let point:PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
        let guageData = StableGaugeData(aggregationTemporality: .cumulative, points: [point])
        let metricData = StableMetricData.createDoubleGauge(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, data: guageData)

        let result = MetricsAdapter.toProtoMetric(stableMetric: metricData)
        guard let value = result?.gauge.dataPoints as? [Opentelemetry_Proto_Metrics_V1_NumberDataPoint] else {
            let actualType = type(of: result?.gauge.dataPoints)
            let errorMessage = "Got wrong type: \(actualType)"
            XCTFail(errorMessage)
            throw errorMessage
        }

        XCTAssertEqual(value.first?.asDouble, pointValue)
    }

    func testToProtoResourceMetricsWithDoubleSum() throws {
        let pointValue: Double = Double.random(in: 1...999)
        let point:PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
        let sumData = StableSumData(aggregationTemporality: .cumulative, points: [point])
        let metricData = StableMetricData.createDoubleSum(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, isMonotonic: false, data: sumData)

        let result = MetricsAdapter.toProtoMetric(stableMetric: metricData)
        guard let value = result?.sum.dataPoints as? [Opentelemetry_Proto_Metrics_V1_NumberDataPoint] else {
            let actualType = type(of: result?.gauge.dataPoints)
            let errorMessage = "Got wrong type: \(actualType)"
            XCTFail(errorMessage)
            throw errorMessage
        }

        XCTAssertEqual(value.first?.asDouble, pointValue)
        XCTAssertEqual(result?.sum.isMonotonic, false)
    }

    func testToProtoResourceMetricsWithHistogram() throws {
        let boundaries = [Double]()
        let sum:Double = Double.random(in: 1...999)
        let min = Double.greatestFiniteMagnitude
        let max:Double = -1
        let count = Int.random(in: 1...100)
        let counts = Array(repeating: 0, count: boundaries.count + 1)
        let histogramPointData = HistogramPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [ExemplarData](), sum: sum, count: UInt64(count), min: min, max: max, boundaries: boundaries, counts: counts, hasMin: count > 0, hasMax: count > 0)
        let points = [histogramPointData]
        let histogramData = StableHistogramData(aggregationTemporality: .cumulative, points: points)
        let metricData = StableMetricData.createHistogram(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, data: histogramData)

        let result = MetricsAdapter.toProtoMetric(stableMetric: metricData)
        guard let value = result?.histogram.dataPoints as? [Opentelemetry_Proto_Metrics_V1_HistogramDataPoint]? else {
            let actualType = type(of: result?.gauge.dataPoints)
            let errorMessage = "Got wrong type: \(actualType)"
            XCTFail(errorMessage)
            throw errorMessage
        }

        XCTAssertEqual(value?.first?.sum, sum)
        XCTAssertEqual(value?.first?.count, UInt64(count))
    }
}

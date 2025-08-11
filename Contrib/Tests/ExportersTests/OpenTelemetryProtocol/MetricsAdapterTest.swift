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

  var testCaseDescription: String {
    String(describing: self)
  }

  func testToProtoResourceMetricsWithLongGuage() throws {
    let pointValue = Int.random(in: 1 ... 999)
    let point: PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
    let guageData = GaugeData(
      aggregationTemporality: .cumulative,
      points: [point]
    )
    let metricData = MetricData.createLongGauge(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: testCaseDescription,
      unit: unit,
      data: guageData
    )

    let result = MetricsAdapter.toProtoMetric(metricData: metricData)
    guard let value = result?.gauge.dataPoints as? [Opentelemetry_Proto_Metrics_V1_NumberDataPoint] else {
      let actualType = type(of: result?.gauge.dataPoints)
      let errorMessage = "Got wrong type: \(actualType)"
      XCTFail(errorMessage)
      throw errorMessage
    }

    XCTAssertEqual(value.first?.asInt, Int64(pointValue))
  }

  func testToProtoResourceMetricsWithLongSum() throws {
    let pointValue = Int.random(in: 1 ... 999)
    let point: PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
    let sumData = SumData(aggregationTemporality: .cumulative, points: [point])
    let metricData = MetricData.createLongSum(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: testCaseDescription,
      unit: unit,
      isMonotonic: true,
      data: sumData
    )

    let result = MetricsAdapter.toProtoMetric(metricData: metricData)
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
    let pointValue = Double.random(in: 1 ... 999)
    let point: PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
    let guageData = GaugeData(
      aggregationTemporality: .cumulative,
      points: [point]
    )
    let metricData = MetricData.createDoubleGauge(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: testCaseDescription,
      unit: unit,
      data: guageData
    )

    let result = MetricsAdapter.toProtoMetric(metricData: metricData)
    guard let value = result?.gauge.dataPoints as? [Opentelemetry_Proto_Metrics_V1_NumberDataPoint] else {
      let actualType = type(of: result?.gauge.dataPoints)
      let errorMessage = "Got wrong type: \(actualType)"
      XCTFail(errorMessage)
      throw errorMessage
    }

    XCTAssertEqual(value.first?.asDouble, pointValue)
  }

  func testToProtoResourceMetricsWithDoubleSum() throws {
    let pointValue = Double.random(in: 1 ... 999)
    let point: PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: pointValue)
    let sumData = SumData(aggregationTemporality: .cumulative, points: [point])
    let metricData = MetricData.createDoubleSum(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: testCaseDescription,
      unit: unit,
      isMonotonic: false,
      data: sumData
    )

    let result = MetricsAdapter.toProtoMetric(metricData: metricData)
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
    let sum = Double.random(in: 1 ... 999)
    let min = Double.greatestFiniteMagnitude
    let max: Double = -1
    let count = Int.random(in: 1 ... 100)
    let counts = Array(repeating: 0, count: boundaries.count + 1)
    let histogramPointData = HistogramPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [ExemplarData](), sum: sum, count: UInt64(count), min: min, max: max, boundaries: boundaries, counts: counts, hasMin: count > 0, hasMax: count > 0)
    let points = [histogramPointData]
    let histogramData = HistogramData(
      aggregationTemporality: .cumulative,
      points: points
    )
    let metricData = MetricData.createHistogram(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: testCaseDescription,
      unit: unit,
      data: histogramData
    )

    let result = MetricsAdapter.toProtoMetric(metricData: metricData)
    guard let value = result?.histogram.dataPoints as? [Opentelemetry_Proto_Metrics_V1_HistogramDataPoint]? else {
      let actualType = type(of: result?.gauge.dataPoints)
      let errorMessage = "Got wrong type: \(actualType)"
      XCTFail(errorMessage)
      throw errorMessage
    }

    XCTAssertEqual(value?.first?.sum, sum)
    XCTAssertEqual(value?.first?.count, UInt64(count))
  }

  func testToProtoResourceMetricsWithExponentialHistogram() throws {
    let positivieBuckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)
    positivieBuckets.downscale(by: 20)
    positivieBuckets.record(value: 10.0)
    positivieBuckets.record(value: 40.0)
    positivieBuckets.record(value: 90.0)
    positivieBuckets.record(value: 100.0)
    let negativeBuckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)

    let expHistogramPointData = ExponentialHistogramPointData(scale: 20, sum: 240.0, zeroCount: 0, hasMin: true, hasMax: true, min: 10.0, max: 100.0, positiveBuckets: positivieBuckets, negativeBuckets: negativeBuckets, startEpochNanos: 0, epochNanos: 1, attributes: [:], exemplars: [])

    let points = [expHistogramPointData]
    let histogramData = ExponentialHistogramData(
      aggregationTemporality: .delta,
      points: points
    )
    let metricData = MetricData.createExponentialHistogram(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: name,
      description: testCaseDescription,
      unit: unit,
      data: histogramData
    )

    let result = MetricsAdapter.toProtoMetric(metricData: metricData)
    guard let value = result?.exponentialHistogram.dataPoints as? [Opentelemetry_Proto_Metrics_V1_ExponentialHistogramDataPoint]? else {
      let actualType = type(of: result?.gauge.dataPoints)
      let errorMessage = "Got wrong type: \(actualType)"
      XCTFail(errorMessage)
      throw errorMessage
    }

    XCTAssertEqual(value?.first?.scale, 20)
    XCTAssertEqual(value?.first?.sum, 240)
    XCTAssertEqual(value?.first?.count, 4)
    XCTAssertEqual(value?.first?.min, 10)
    XCTAssertEqual(value?.first?.max, 100)
    XCTAssertEqual(value?.first?.zeroCount, 0)
  }
}

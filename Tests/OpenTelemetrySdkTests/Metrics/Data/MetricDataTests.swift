//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class MetricDataTests: XCTestCase {
  let resource = Resource(attributes: ["foo": AttributeValue("bar")])
  let instrumentationScopeInfo = InstrumentationScopeInfo(name: "test")
  let metricName = "name"
  let metricDescription = "description"
  let emptyPointData = [PointData]()
  let unit = "unit"

  func testStableMetricDataCreation() {
    let type = MetricDataType.Summary
    let data = MetricData.Data(
      aggregationTemporality: .delta,
      points: emptyPointData
    )

    let metricData = MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      type: type,
      isMonotonic: false,
      data: data
    )

    assertCommon(metricData)
    XCTAssertEqual(metricData.type, type)
    XCTAssertEqual(metricData.data, data)
    XCTAssertEqual(metricData.data.aggregationTemporality, .delta)
    XCTAssertEqual(metricData.isMonotonic, false)
  }

  func testEmptyStableMetricData() {
    XCTAssertEqual(
      MetricData.empty,
      MetricData(
        resource: Resource.empty,
        instrumentationScopeInfo: InstrumentationScopeInfo(),
        name: "",
        description: "",
        unit: "",
        type: .Summary,
        isMonotonic: false,
        data: MetricData
          .Data(aggregationTemporality: .cumulative, points: [PointData]())
      )
    )
  }

  func testCreateExponentialHistogram() {
    let type = MetricDataType.ExponentialHistogram
    let histogramData = ExponentialHistogramData(
      aggregationTemporality: .delta,
      points: emptyPointData
    )

    let metricData = MetricData.createExponentialHistogram(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: histogramData
    )

    assertCommon(metricData)
    XCTAssertEqual(metricData.type, type)
    XCTAssertEqual(metricData.data, histogramData)
    XCTAssertEqual(metricData.data.aggregationTemporality, .delta)
    XCTAssertEqual(metricData.isMonotonic, false)
  }

  func testCreateHistogram() {
    let type = MetricDataType.Histogram

    let boundaries = [Double]()
    let sum: Double = 0
    let min = Double.greatestFiniteMagnitude
    let max: Double = -1
    let count = 0
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
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: histogramData
    )

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

  func testCreateExponentialHistogramData() {
    let type = MetricDataType.ExponentialHistogram
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
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: histogramData
    )

    assertCommon(metricData)
    XCTAssertEqual(metricData.type, type)
    XCTAssertEqual(metricData.data, histogramData)
    XCTAssertEqual(metricData.data.aggregationTemporality, .delta)
    XCTAssertEqual(metricData.isMonotonic, false)

    XCTAssertFalse(metricData.isEmpty())
    let histogramMetricData = metricData.data.points.first as! ExponentialHistogramPointData
    XCTAssertEqual(histogramMetricData.scale, 20)
    XCTAssertEqual(histogramMetricData.sum, 240)
    XCTAssertEqual(histogramMetricData.count, 4)
    XCTAssertEqual(histogramMetricData.min, 10)
    XCTAssertEqual(histogramMetricData.max, 100)
    XCTAssertEqual(histogramMetricData.zeroCount, 0)
  }

  func testCreateDoubleGuage() {
    let type = MetricDataType.DoubleGauge
    let d = 22.22222

    let point: PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: d)
    let guageData = GaugeData(
      aggregationTemporality: .cumulative,
      points: [point]
    )
    let metricData = MetricData.createDoubleGauge(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: guageData
    )

    assertCommon(metricData)
    XCTAssertEqual(metricData.type, type)
    XCTAssertEqual(metricData.data.points.first, point)
    XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
    XCTAssertEqual(metricData.isMonotonic, false)
  }

  func testCreateDoubleSum() {
    let type = MetricDataType.DoubleSum
    let d = 44.4444

    let point: PointData = DoublePointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: d)
    let sumData = SumData(aggregationTemporality: .cumulative, points: [point])
    let metricData = MetricData.createDoubleSum(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      isMonotonic: true,
      data: sumData
    )

    assertCommon(metricData)
    XCTAssertEqual(metricData.type, type)
    XCTAssertEqual(metricData.data.points.first, point)
    XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
    XCTAssertEqual(metricData.isMonotonic, true)
  }

  func testCreateLongGuage() {
    let type = MetricDataType.LongGauge
    let point: PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 33)
    let guageData = GaugeData(
      aggregationTemporality: .cumulative,
      points: [point]
    )

    let metricData = MetricData.createLongGauge(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: guageData
    )

    assertCommon(metricData)
    XCTAssertEqual(metricData.type, type)
    XCTAssertEqual(metricData.data.points.first, point)
    XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
    XCTAssertEqual(metricData.isMonotonic, false)
  }

  func testCreateLongSum() {
    let type = MetricDataType.LongSum
    let point: PointData = LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 55)
    let sumData = SumData(aggregationTemporality: .cumulative, points: [point])

    let metricData = MetricData.createLongSum(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      isMonotonic: true,
      data: sumData
    )

    assertCommon(metricData)
    XCTAssertEqual(metricData.type, type)
    XCTAssertEqual(metricData.data.points.first, point)
    XCTAssertEqual(metricData.data.aggregationTemporality, .cumulative)
    XCTAssertEqual(metricData.isMonotonic, true)
  }

  func assertCommon(_ metricData: MetricData) {
    XCTAssertEqual(metricData.resource, resource)
    XCTAssertEqual(metricData.instrumentationScopeInfo, instrumentationScopeInfo)
    XCTAssertEqual(metricData.name, metricName)
    XCTAssertEqual(metricData.description, metricDescription)
    XCTAssertEqual(metricData.unit, unit)
  }
}

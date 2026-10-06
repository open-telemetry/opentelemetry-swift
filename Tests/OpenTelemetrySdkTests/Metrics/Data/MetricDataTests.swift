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

  // MARK: - Creation

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

  // MARK: - Codable

  func testLongGaugeMetricDataCodable() {
    let point = LongPointData(
      startEpochNanos: 0,
      endEpochNanos: 1,
      attributes: [:],
      exemplars: [],
      value: 33
    )
    let metricData = MetricData.createLongGauge(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: GaugeData(aggregationTemporality: .cumulative, points: [point])
    )

    assertMetricDataCodable(metricData) { decoded in
      let decodedPoint = try XCTUnwrap(decoded.data.points.first as? LongPointData)
      XCTAssertEqual(decodedPoint.value, 33)
      XCTAssertEqual(decoded.isMonotonic, false)
    }
  }

  func testLongSumMetricDataCodable() {
    let point = LongPointData(
      startEpochNanos: 0,
      endEpochNanos: 1,
      attributes: [:],
      exemplars: [],
      value: 55
    )
    let metricData = MetricData.createLongSum(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      isMonotonic: true,
      data: SumData(aggregationTemporality: .cumulative, points: [point])
    )

    assertMetricDataCodable(metricData) { decoded in
      let decodedPoint = try XCTUnwrap(decoded.data.points.first as? LongPointData)
      XCTAssertEqual(decodedPoint.value, 55)
      XCTAssertEqual(decoded.isMonotonic, true)
    }
  }

  func testDoubleGaugeMetricDataCodable() {
    let point = DoublePointData(
      startEpochNanos: 0,
      endEpochNanos: 1,
      attributes: [:],
      exemplars: [],
      value: 22.22222
    )
    let metricData = MetricData.createDoubleGauge(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: GaugeData(aggregationTemporality: .cumulative, points: [point])
    )

    assertMetricDataCodable(metricData) { decoded in
      let decodedPoint = try XCTUnwrap(decoded.data.points.first as? DoublePointData)
      XCTAssertEqual(decodedPoint.value, 22.22222)
      XCTAssertEqual(decoded.isMonotonic, false)
    }
  }

  func testDoubleSumMetricDataCodable() {
    let point = DoublePointData(
      startEpochNanos: 0,
      endEpochNanos: 1,
      attributes: [:],
      exemplars: [],
      value: 44.4444
    )
    let metricData = MetricData.createDoubleSum(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      isMonotonic: true,
      data: SumData(aggregationTemporality: .cumulative, points: [point])
    )

    assertMetricDataCodable(metricData) { decoded in
      let decodedPoint = try XCTUnwrap(decoded.data.points.first as? DoublePointData)
      XCTAssertEqual(decodedPoint.value, 44.4444)
      XCTAssertEqual(decoded.isMonotonic, true)
    }
  }

  func testSummaryMetricDataCodable() {
    let point = SummaryPointData(
      startEpochNanos: 0,
      endEpochNanos: 1,
      attributes: [:],
      count: 100,
      sum: 2.2,
      percentileValues: [ValueAtQuantile(quantile: 1.1, value: 1.3)]
    )
    let metricData = MetricData(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      type: .Summary,
      isMonotonic: false,
      data: SummaryData(aggregationTemporality: .cumulative, points: [point])
    )

    assertMetricDataCodable(metricData) { decoded in
      let decodedPoint = try XCTUnwrap(decoded.data.points.first as? SummaryPointData)
      XCTAssertEqual(decodedPoint.count, 100)
      XCTAssertEqual(decodedPoint.sum, 2.2)
      XCTAssertEqual(decodedPoint.values.count, 1)
      XCTAssertEqual(decodedPoint.values[0].quantile, 1.1)
      XCTAssertEqual(decodedPoint.values[0].value, 1.3)
      XCTAssertEqual(decoded.isMonotonic, false)
    }
  }

  func testHistogramMetricDataCodable() {
    let point = HistogramPointData(
      startEpochNanos: 0,
      endEpochNanos: 1,
      attributes: [:],
      exemplars: [],
      sum: 10.0,
      count: 4,
      min: 1.0,
      max: 4.0,
      boundaries: [1.0, 2.0, 3.0],
      counts: [1, 1, 1, 1],
      hasMin: true,
      hasMax: true
    )
    let metricData = MetricData.createHistogram(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: HistogramData(aggregationTemporality: .cumulative, points: [point])
    )

    assertMetricDataCodable(metricData) { decoded in
      let decodedPoint = try XCTUnwrap(decoded.data.points.first as? HistogramPointData)
      XCTAssertEqual(decodedPoint.sum, 10.0)
      XCTAssertEqual(decodedPoint.count, 4)
      XCTAssertEqual(decodedPoint.min, 1.0)
      XCTAssertEqual(decodedPoint.max, 4.0)
      XCTAssertEqual(decodedPoint.boundaries, [1.0, 2.0, 3.0])
      XCTAssertEqual(decodedPoint.counts, [1, 1, 1, 1])
      XCTAssertEqual(decoded.isMonotonic, false)
    }
  }

  func testExponentialHistogramMetricDataCodable() {
    let positiveBuckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)
    positiveBuckets.downscale(by: 20)
    positiveBuckets.record(value: 10.0)
    positiveBuckets.record(value: 40.0)
    positiveBuckets.record(value: 90.0)
    positiveBuckets.record(value: 100.0)

    let negativeBuckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)

    let expHistogramPointData = ExponentialHistogramPointData(
      scale: 20,
      sum: 240.0,
      zeroCount: 0,
      hasMin: true,
      hasMax: true,
      min: 10.0,
      max: 100.0,
      positiveBuckets: positiveBuckets,
      negativeBuckets: negativeBuckets,
      startEpochNanos: 0,
      epochNanos: 1,
      attributes: [:],
      exemplars: []
    )

    let metricData = MetricData.createExponentialHistogram(
      resource: resource,
      instrumentationScopeInfo: instrumentationScopeInfo,
      name: metricName,
      description: metricDescription,
      unit: unit,
      data: ExponentialHistogramData(
        aggregationTemporality: .delta,
        points: [expHistogramPointData]
      )
    )

    do {
      let encoded = try JSONEncoder().encode(metricData)
      let decoded = try JSONDecoder().decode(MetricData.self, from: encoded)

      assertCommon(decoded)
      XCTAssertEqual(decoded.type, .ExponentialHistogram)
      XCTAssertEqual(decoded.data.aggregationTemporality, .delta)
      XCTAssertEqual(decoded.isMonotonic, false)
      XCTAssertEqual(decoded.data.points.count, 1)

      let point = try XCTUnwrap(decoded.data.points.first as? ExponentialHistogramPointData)
      XCTAssertEqual(point.scale, 20)
      XCTAssertEqual(point.sum, 240)
      XCTAssertEqual(point.count, 4)
      XCTAssertEqual(point.min, 10)
      XCTAssertEqual(point.max, 100)
      XCTAssertEqual(point.zeroCount, 0)
    } catch {
      XCTFail(String(describing: error))
    }
  }

  // MARK: - Helpers

  func assertCommon(_ metricData: MetricData) {
    XCTAssertEqual(metricData.resource, resource)
    XCTAssertEqual(metricData.instrumentationScopeInfo, instrumentationScopeInfo)
    XCTAssertEqual(metricData.name, metricName)
    XCTAssertEqual(metricData.description, metricDescription)
    XCTAssertEqual(metricData.unit, unit)
  }

  private func assertMetricDataCodable(
    _ metricData: MetricData,
    verify: (MetricData) throws -> Void
  ) {
    do {
      let encoded = try JSONEncoder().encode(metricData)
      let decoded = try JSONDecoder().decode(MetricData.self, from: encoded)

      assertCommon(decoded)
      XCTAssertEqual(decoded.type, metricData.type)
      XCTAssertEqual(decoded.data.aggregationTemporality, metricData.data.aggregationTemporality)
      XCTAssertEqual(decoded.data.points.count, 1)
      try verify(decoded)
    } catch {
      XCTFail(String(describing: error))
    }
  }
}

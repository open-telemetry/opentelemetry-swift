//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

/// Imports OpenTelemetrySdk without @testable so this file only compiles
/// while the initializers a custom MetricProducer needs stay public.
final class MetricDataPublicInitTests: XCTestCase {
  private struct PrecomputedMetricProducer: MetricProducer {
    let metrics: [MetricData]

    func collectAllMetrics() -> [MetricData] {
      metrics
    }
  }

  private let resource = Resource(attributes: ["service.name": AttributeValue("test")])
  private let scope = InstrumentationScopeInfo(name: "precomputed")
  private let attributes: [String: AttributeValue] = ["key": AttributeValue("value")]
  private let startEpochNanos: UInt64 = 1_000_000_000
  private let endEpochNanos: UInt64 = 2_000_000_000

  func testProducerReturnsSumWithGivenTimeRange() throws {
    let point = DoublePointData(
      startEpochNanos: startEpochNanos,
      endEpochNanos: endEpochNanos,
      attributes: attributes,
      exemplars: [],
      value: 3.5
    )
    let metric = MetricData.createDoubleSum(
      resource: resource,
      instrumentationScopeInfo: scope,
      name: "sum",
      description: "description",
      unit: "1",
      isMonotonic: true,
      data: SumData(aggregationTemporality: .delta, points: [point])
    )

    let collected = PrecomputedMetricProducer(metrics: [metric]).collectAllMetrics()

    XCTAssertEqual(collected.count, 1)
    XCTAssertEqual(collected[0].type, .DoubleSum)
    XCTAssertTrue(collected[0].isMonotonic)
    XCTAssertEqual(collected[0].data.aggregationTemporality, .delta)
    let collectedPoint = try XCTUnwrap(collected[0].data.points.first as? DoublePointData)
    XCTAssertEqual(collectedPoint.startEpochNanos, startEpochNanos)
    XCTAssertEqual(collectedPoint.endEpochNanos, endEpochNanos)
    XCTAssertEqual(collectedPoint.attributes, attributes)
    XCTAssertEqual(collectedPoint.value, 3.5)
  }

  func testLongSumAndGaugesCanBeCreated() {
    let longPoint = LongPointData(
      startEpochNanos: startEpochNanos,
      endEpochNanos: endEpochNanos,
      attributes: attributes,
      exemplars: [],
      value: 7
    )
    let doublePoint = DoublePointData(
      startEpochNanos: startEpochNanos,
      endEpochNanos: endEpochNanos,
      attributes: attributes,
      exemplars: [],
      value: 1.5
    )

    let longSum = MetricData.createLongSum(
      resource: resource,
      instrumentationScopeInfo: scope,
      name: "long_sum",
      description: "description",
      unit: "1",
      isMonotonic: false,
      data: SumData(aggregationTemporality: .cumulative, points: [longPoint])
    )
    let longGauge = MetricData.createLongGauge(
      resource: resource,
      instrumentationScopeInfo: scope,
      name: "long_gauge",
      description: "description",
      unit: "1",
      data: GaugeData(aggregationTemporality: .cumulative, points: [longPoint])
    )
    let doubleGauge = MetricData.createDoubleGauge(
      resource: resource,
      instrumentationScopeInfo: scope,
      name: "double_gauge",
      description: "description",
      unit: "1",
      data: GaugeData(aggregationTemporality: .cumulative, points: [doublePoint])
    )

    XCTAssertEqual(longSum.type, .LongSum)
    XCTAssertFalse(longSum.isMonotonic)
    XCTAssertEqual(longGauge.type, .LongGauge)
    XCTAssertEqual(doubleGauge.type, .DoubleGauge)
    XCTAssertEqual((longGauge.data.points.first as? LongPointData)?.value, 7)
    XCTAssertEqual((doubleGauge.data.points.first as? DoublePointData)?.value, 1.5)
  }

  func testHistogramCanBeCreated() throws {
    let point = HistogramPointData(
      startEpochNanos: startEpochNanos,
      endEpochNanos: endEpochNanos,
      attributes: attributes,
      exemplars: [],
      sum: 15.0,
      count: 3,
      min: 1.0,
      max: 10.0,
      boundaries: [5.0],
      counts: [2, 1],
      hasMin: true,
      hasMax: true
    )

    let metric = MetricData.createHistogram(
      resource: resource,
      instrumentationScopeInfo: scope,
      name: "histogram",
      description: "description",
      unit: "ms",
      data: HistogramData(aggregationTemporality: .delta, points: [point])
    )

    XCTAssertEqual(metric.type, .Histogram)
    let collectedPoint = try XCTUnwrap(metric.data.points.first as? HistogramPointData)
    XCTAssertEqual(collectedPoint.startEpochNanos, startEpochNanos)
    XCTAssertEqual(collectedPoint.endEpochNanos, endEpochNanos)
    XCTAssertEqual(collectedPoint.counts, [2, 1])
    XCTAssertEqual(collectedPoint.sum, 15.0)
  }

  func testMetricDataInitializerAcceptsCustomData() {
    let metric = MetricData(
      resource: resource,
      instrumentationScopeInfo: scope,
      name: "custom",
      description: "description",
      unit: "1",
      type: .DoubleGauge,
      isMonotonic: false,
      data: MetricData.Data(aggregationTemporality: .cumulative, points: [])
    )

    XCTAssertEqual(metric.name, "custom")
    XCTAssertTrue(metric.data.points.isEmpty)
  }
}

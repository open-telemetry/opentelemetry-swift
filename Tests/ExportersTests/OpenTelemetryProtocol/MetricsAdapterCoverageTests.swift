/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetrySdk
import XCTest

final class MetricsAdapterCoverageTests: XCTestCase {
  private let resource = Resource(attributes: ["service": .string("svc")])
  private let scope = InstrumentationScopeInfo(name: "scope")

  func testToProtoMetricReturnsNilWhenPointsEmpty() {
    let data = MetricData(resource: resource,
                          instrumentationScopeInfo: scope,
                          name: "empty",
                          description: "",
                          unit: "",
                          type: .LongSum,
                          isMonotonic: false,
                          data: MetricData.Data(aggregationTemporality: .cumulative, points: []))
    XCTAssertNil(MetricsAdapter.toProtoMetric(metricData: data))
  }

  func testConvertToProtoEnumCumulativeAndDelta() {
    XCTAssertEqual(AggregationTemporality.cumulative.convertToProtoEnum(), .cumulative)
    XCTAssertEqual(AggregationTemporality.delta.convertToProtoEnum(), .delta)
  }

  func testToProtoMetricForSummary() {
    let summaryPoint = SummaryPointData(
      startEpochNanos: 100,
      endEpochNanos: 200,
      attributes: ["k": .string("v")],
      count: 4,
      sum: 12.5,
      percentileValues: [ValueAtQuantile(quantile: 0.5, value: 2.0),
                        ValueAtQuantile(quantile: 0.95, value: 4.0)]
    )
    let data = MetricData(resource: resource,
                          instrumentationScopeInfo: scope,
                          name: "summary-metric",
                          description: "",
                          unit: "",
                          type: .Summary,
                          isMonotonic: false,
                          data: MetricData.Data(aggregationTemporality: .cumulative,
                                                points: [summaryPoint]))
    let proto = MetricsAdapter.toProtoMetric(metricData: data)
    XCTAssertEqual(proto?.name, "summary-metric")
    XCTAssertEqual(proto?.summary.dataPoints.count, 1)
    XCTAssertEqual(proto?.summary.dataPoints.first?.count, 4)
    XCTAssertEqual(proto?.summary.dataPoints.first?.sum, 12.5)
    XCTAssertEqual(proto?.summary.dataPoints.first?.quantileValues.count, 2)
  }

  func testToProtoResourceMetricsWithDeltaTemporality() {
    let point = LongPointData(startEpochNanos: 1, endEpochNanos: 2, attributes: [:], exemplars: [], value: 3)
    let sumData = SumData(aggregationTemporality: .delta, points: [point])
    let data = MetricData.createLongSum(resource: resource,
                                        instrumentationScopeInfo: scope,
                                        name: "sum-delta",
                                        description: "",
                                        unit: "",
                                        isMonotonic: true,
                                        data: sumData)
    let result = MetricsAdapter.toProtoResourceMetrics(metricData: [data])
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.scopeMetrics.first?.metrics.first?.sum.aggregationTemporality, .delta)
  }

  func testToProtoMetricWithLongExemplarPopulatesProtoExemplar() {
    let spanContext = SpanContext.create(traceId: TraceId.random(),
                                         spanId: SpanId.random(),
                                         traceFlags: TraceFlags(),
                                         traceState: TraceState())
    let exemplar = LongExemplarData(value: 7,
                                    epochNanos: 123,
                                    filteredAttributes: ["ek": .string("ev")],
                                    spanContext: spanContext)
    let point = LongPointData(startEpochNanos: 1,
                              endEpochNanos: 2,
                              attributes: [:],
                              exemplars: [exemplar],
                              value: 42)
    let sumData = SumData(aggregationTemporality: .cumulative, points: [point])
    let data = MetricData.createLongSum(resource: resource,
                                        instrumentationScopeInfo: scope,
                                        name: "sum-exemplar",
                                        description: "",
                                        unit: "",
                                        isMonotonic: true,
                                        data: sumData)
    let proto = MetricsAdapter.toProtoMetric(metricData: data)
    let exemplars = proto?.sum.dataPoints.first?.exemplars ?? []
    XCTAssertEqual(exemplars.count, 1)
    XCTAssertEqual(exemplars.first?.filteredAttributes.count, 1)
    // Exemplar carries span context.
    XCTAssertFalse(exemplars.first?.traceID.isEmpty ?? true)
  }

  func testToProtoMetricWithDoubleExemplarOnHistogram() {
    let exemplar = DoubleExemplarData(value: 0.5,
                                      epochNanos: 999,
                                      filteredAttributes: [:],
                                      spanContext: nil)
    let hp = HistogramPointData(startEpochNanos: 1,
                                endEpochNanos: 2,
                                attributes: [:],
                                exemplars: [exemplar],
                                sum: 1.0,
                                count: 2,
                                min: 0.0,
                                max: 1.0,
                                boundaries: [0.5],
                                counts: [1, 1],
                                hasMin: true,
                                hasMax: true)
    let histogramData = HistogramData(aggregationTemporality: .cumulative, points: [hp])
    let data = MetricData.createHistogram(resource: resource,
                                          instrumentationScopeInfo: scope,
                                          name: "hist",
                                          description: "",
                                          unit: "",
                                          data: histogramData)
    let proto = MetricsAdapter.toProtoMetric(metricData: data)
    XCTAssertEqual(proto?.histogram.dataPoints.first?.exemplars.count, 1)
  }

  func testToProtoMetricWithLongExemplarOnHistogram() {
    // LongExemplarData exercises the `$0 as? LongExemplarData` branch inside
    // injectPointData(protoHistogramPoint:...).
    let exemplar = LongExemplarData(value: 3,
                                    epochNanos: 999,
                                    filteredAttributes: ["ek": .string("ev")],
                                    spanContext: nil)
    let hp = HistogramPointData(startEpochNanos: 1,
                                endEpochNanos: 2,
                                attributes: [:],
                                exemplars: [exemplar],
                                sum: 3.0, count: 1,
                                min: 3.0, max: 3.0,
                                boundaries: [5],
                                counts: [1, 0],
                                hasMin: true, hasMax: true)
    let hd = HistogramData(aggregationTemporality: .cumulative, points: [hp])
    let md = MetricData.createHistogram(resource: resource,
                                        instrumentationScopeInfo: scope,
                                        name: "hist-l",
                                        description: "",
                                        unit: "",
                                        data: hd)
    let proto = MetricsAdapter.toProtoMetric(metricData: md)
    XCTAssertEqual(proto?.histogram.dataPoints.first?.exemplars.count, 1)
  }

  func testToProtoMetricWithExemplarSpanContextPopulatesTraceIds() {
    let spanContext = SpanContext.create(traceId: TraceId.random(),
                                         spanId: SpanId.random(),
                                         traceFlags: TraceFlags(),
                                         traceState: TraceState())
    let exemplar = DoubleExemplarData(value: 1.0,
                                      epochNanos: 100,
                                      filteredAttributes: [:],
                                      spanContext: spanContext)
    let hp = HistogramPointData(startEpochNanos: 1, endEpochNanos: 2,
                                attributes: [:], exemplars: [exemplar],
                                sum: 1.0, count: 1,
                                min: 1.0, max: 1.0,
                                boundaries: [2], counts: [1, 0],
                                hasMin: true, hasMax: true)
    let md = MetricData.createHistogram(resource: resource,
                                        instrumentationScopeInfo: scope,
                                        name: "h-span-ctx", description: "", unit: "",
                                        data: HistogramData(aggregationTemporality: .cumulative, points: [hp]))
    let proto = MetricsAdapter.toProtoMetric(metricData: md)
    XCTAssertFalse(proto?.histogram.dataPoints.first?.exemplars.first?.spanID.isEmpty ?? true)
    XCTAssertFalse(proto?.histogram.dataPoints.first?.exemplars.first?.traceID.isEmpty ?? true)
  }

  func testToProtoMetricMismatchedPointsAreSkipped() {
    // A LongGauge metric with a DoublePointData should hit the `break` guard
    // and produce a metric with empty gauge data points.
    let wrongPoint = DoublePointData(startEpochNanos: 1, endEpochNanos: 2, attributes: [:], exemplars: [], value: 1.0)
    let data = MetricData(resource: resource,
                          instrumentationScopeInfo: scope,
                          name: "g",
                          description: "",
                          unit: "",
                          type: .LongGauge,
                          isMonotonic: false,
                          data: MetricData.Data(aggregationTemporality: .cumulative,
                                                points: [wrongPoint]))
    let proto = MetricsAdapter.toProtoMetric(metricData: data)
    XCTAssertEqual(proto?.gauge.dataPoints.count, 0)
  }

  func testToProtoResourceMetricsWithMultipleResources() {
    let res2 = Resource(attributes: ["service": .string("svc2")])
    let sumA = SumData(aggregationTemporality: .cumulative,
                       points: [LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 1)])
    let sumB = SumData(aggregationTemporality: .cumulative,
                       points: [LongPointData(startEpochNanos: 0, endEpochNanos: 1, attributes: [:], exemplars: [], value: 2)])
    let d1 = MetricData.createLongSum(resource: resource, instrumentationScopeInfo: scope,
                                      name: "a", description: "", unit: "", isMonotonic: true, data: sumA)
    let d2 = MetricData.createLongSum(resource: res2, instrumentationScopeInfo: scope,
                                      name: "b", description: "", unit: "", isMonotonic: true, data: sumB)
    let result = MetricsAdapter.toProtoResourceMetrics(metricData: [d1, d2])
    XCTAssertEqual(result.count, 2)
  }
}

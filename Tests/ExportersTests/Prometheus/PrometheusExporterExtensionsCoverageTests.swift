/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import PrometheusExporter
import XCTest

/// Exercises `PrometheusExporterExtensions.writeMetricsCollection` across all
/// `MetricDataType` branches by feeding the exporter an accumulated batch and
/// then reading the serialized output. Drives both the type-matched path (which
/// emits text) and the `guard ... else { break }` mismatches (silent skip).
final class PrometheusExporterExtensionsCoverageTests: XCTestCase {
  private let resource = Resource(attributes: ["service": .string("svc")])
  private let scope = InstrumentationScopeInfo(name: "scope")

  private func exporterWith(_ batches: [[MetricData]]) -> PrometheusExporter {
    let options = PrometheusExporterOptions(url: "http://localhost/metrics/")
    let exporter = PrometheusExporter(options: options)
    batches.forEach { _ = exporter.export(metrics: $0) }
    return exporter
  }

  private func makeLongSumMetric() -> MetricData {
    let p = LongPointData(startEpochNanos: 0, endEpochNanos: 1,
                          attributes: ["k": .string("v")],
                          exemplars: [], value: 5)
    return MetricData.createLongSum(resource: resource,
                                    instrumentationScopeInfo: scope,
                                    name: "long_sum",
                                    description: "sum",
                                    unit: "1",
                                    isMonotonic: true,
                                    data: SumData(aggregationTemporality: .cumulative, points: [p]))
  }

  private func makeDoubleSumMetric() -> MetricData {
    let p = DoublePointData(startEpochNanos: 0, endEpochNanos: 1,
                            attributes: ["k": .string("v")],
                            exemplars: [], value: 1.5)
    return MetricData.createDoubleSum(resource: resource,
                                      instrumentationScopeInfo: scope,
                                      name: "double_sum",
                                      description: "",
                                      unit: "",
                                      isMonotonic: true,
                                      data: SumData(aggregationTemporality: .cumulative, points: [p]))
  }

  private func makeLongGaugeMetric() -> MetricData {
    let p = LongPointData(startEpochNanos: 0, endEpochNanos: 1,
                          attributes: ["k": .string("v")],
                          exemplars: [], value: 10)
    return MetricData.createLongGauge(resource: resource,
                                      instrumentationScopeInfo: scope,
                                      name: "long_gauge",
                                      description: "",
                                      unit: "",
                                      data: GaugeData(aggregationTemporality: .cumulative, points: [p]))
  }

  private func makeDoubleGaugeMetric() -> MetricData {
    let p = DoublePointData(startEpochNanos: 0, endEpochNanos: 1,
                            attributes: ["k": .string("v")],
                            exemplars: [], value: 2.25)
    return MetricData.createDoubleGauge(resource: resource,
                                        instrumentationScopeInfo: scope,
                                        name: "double_gauge",
                                        description: "",
                                        unit: "",
                                        data: GaugeData(aggregationTemporality: .cumulative, points: [p]))
  }

  private func makeHistogramMetric() -> MetricData {
    let hp = HistogramPointData(startEpochNanos: 0, endEpochNanos: 1,
                                attributes: ["k": .string("v")],
                                exemplars: [],
                                sum: 6, count: 3,
                                min: 1, max: 5,
                                boundaries: [2, 4],
                                counts: [1, 1, 1],
                                hasMin: true, hasMax: true)
    return MetricData.createHistogram(resource: resource,
                                      instrumentationScopeInfo: scope,
                                      name: "hist",
                                      description: "",
                                      unit: "",
                                      data: HistogramData(aggregationTemporality: .cumulative,
                                                          points: [hp]))
  }

  private func makeSummaryMetric() -> MetricData {
    let sp = SummaryPointData(startEpochNanos: 0, endEpochNanos: 1,
                              attributes: ["k": .string("v")],
                              count: 3, sum: 9,
                              percentileValues: [
                                ValueAtQuantile(quantile: 0.5, value: 2),
                                ValueAtQuantile(quantile: 0.95, value: 5)
                              ])
    let data = SummaryData(aggregationTemporality: .cumulative, points: [sp])
    return MetricData(resource: resource,
                      instrumentationScopeInfo: scope,
                      name: "summary",
                      description: "",
                      unit: "",
                      type: .Summary,
                      isMonotonic: false,
                      data: data)
  }

  func testWriteLongSumProducesCounterLines() {
    let exporter = exporterWith([[makeLongSumMetric()]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE long_sum counter"))
    XCTAssertTrue(out.contains("long_sum{k=\"v\"}"))
  }

  func testWriteDoubleSumProducesCounter() {
    let exporter = exporterWith([[makeDoubleSumMetric()]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE double_sum counter"))
    XCTAssertTrue(out.contains("double_sum{k=\"v\"}"))
  }

  func testWriteLongGaugeProducesGauge() {
    let exporter = exporterWith([[makeLongGaugeMetric()]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE long_gauge gauge"))
  }

  func testWriteDoubleGaugeProducesGauge() {
    let exporter = exporterWith([[makeDoubleGaugeMetric()]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE double_gauge gauge"))
  }

  func testWriteHistogramProducesHistogramLines() {
    let exporter = exporterWith([[makeHistogramMetric()]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE hist histogram"))
    XCTAssertTrue(out.contains("hist_sum"))
    XCTAssertTrue(out.contains("hist_count"))
    XCTAssertTrue(out.contains("le=\"+Inf\""))
  }

  func testWriteSummaryProducesSummaryLines() {
    let exporter = exporterWith([[makeSummaryMetric()]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE summary summary"))
    XCTAssertTrue(out.contains("summary_sum"))
    XCTAssertTrue(out.contains("summary_count"))
  }

  func testWriteMetricsCollectionHandlesMixedBatch() {
    let exporter = exporterWith([[
      makeLongSumMetric(),
      makeDoubleGaugeMetric(),
      makeHistogramMetric()
    ]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE long_sum counter"))
    XCTAssertTrue(out.contains("# TYPE double_gauge gauge"))
    XCTAssertTrue(out.contains("# TYPE hist histogram"))
  }

  func testWriteMetricsCollectionReturnsEmptyStringWhenNoExports() {
    let exporter = exporterWith([])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertEqual(out, "")
  }

  func testWriteExponentialHistogramProducesHistogramLines() {
    // The `.ExponentialHistogram` branch in writeMetricsCollection casts the
    // point as `HistogramPointData` — so a MetricData typed as
    // .ExponentialHistogram carrying a HistogramPointData is the straightforward
    // way to exercise it from this test target.
    let hp = HistogramPointData(startEpochNanos: 0, endEpochNanos: 1,
                                attributes: ["k": .string("v")],
                                exemplars: [],
                                sum: 6, count: 3,
                                min: 1, max: 5,
                                boundaries: [2, 4],
                                counts: [1, 1, 1],
                                hasMin: true, hasMax: true)
    let metric = MetricData(resource: resource,
                            instrumentationScopeInfo: scope,
                            name: "exp_hist",
                            description: "",
                            unit: "",
                            type: .ExponentialHistogram,
                            isMonotonic: false,
                            data: HistogramData(aggregationTemporality: .cumulative,
                                                points: [hp]))
    let exporter = exporterWith([[metric]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertTrue(out.contains("# TYPE exp_hist histogram"))
    XCTAssertTrue(out.contains("exp_hist_sum"))
  }

  func testWriteLongSumFallsThroughWhenPointIsDouble() {
    // LongSum with a DoublePointData hits the `break` in the guard-let.
    let wrongPoint = DoublePointData(startEpochNanos: 0, endEpochNanos: 1,
                                     attributes: [:], exemplars: [], value: 1.0)
    let metric = MetricData(resource: resource,
                            instrumentationScopeInfo: scope,
                            name: "mismatched",
                            description: "",
                            unit: "",
                            type: .LongSum,
                            isMonotonic: true,
                            data: SumData(aggregationTemporality: .cumulative, points: [wrongPoint]))
    let exporter = exporterWith([[metric]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    // The mismatched point is skipped (empty values).
    XCTAssertFalse(out.contains("mismatched{"))
  }

  func testWriteLongGaugeFallsThroughWhenPointIsDouble() {
    let wrongPoint = DoublePointData(startEpochNanos: 0, endEpochNanos: 1,
                                     attributes: [:], exemplars: [], value: 1.0)
    let metric = MetricData(resource: resource,
                            instrumentationScopeInfo: scope,
                            name: "mismatched-gauge",
                            description: "",
                            unit: "",
                            type: .LongGauge,
                            isMonotonic: false,
                            data: GaugeData(aggregationTemporality: .cumulative, points: [wrongPoint]))
    let exporter = exporterWith([[metric]])
    let out = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
    XCTAssertFalse(out.contains("mismatched-gauge{"))
  }
}

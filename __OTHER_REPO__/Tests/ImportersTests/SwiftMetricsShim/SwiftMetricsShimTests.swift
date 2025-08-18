/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import CoreMetrics
@testable import SwiftMetricsShim
import XCTest

class MetricExporterMock: MetricExporter {
  func flush() -> OpenTelemetrySdk.ExportResult {
    .success
  }

  func shutdown() -> OpenTelemetrySdk.ExportResult {
    .success
  }

  func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    return AggregationTemporality.cumulative
  }

  let onExport: ([MetricData]) -> ExportResult
  init(onExport: @escaping ([MetricData]) -> ExportResult) {
    self.onExport = onExport
  }

  func export(metrics: [MetricData]) -> ExportResult {
    return onExport(metrics)
  }
}

class SwiftMetricsShimTests: XCTestCase {
  var mockExporter: MetricExporterMock! = nil
  let provider: MeterSdk! = nil
  var stableMetrics = [MetricData]()
  var metrics: OpenTelemetrySwiftMetrics! = nil
  var metricsExportExpectation: XCTestExpectation! = nil
  override func setUp() {
    super.setUp()
    metricsExportExpectation = expectation(description: "metrics exported")

    var reader: PeriodicMetricReaderSdk! = nil
    stableMetrics = [MetricData]()
    mockExporter = MetricExporterMock { metrics in
      self.stableMetrics = metrics
      self.metricsExportExpectation.fulfill()
      _ = reader.shutdown()
      return .success
    }

    reader = PeriodicMetricReaderSdk(
      exporter: mockExporter,
      exportInterval: 0.5
    )

    let provider = MeterProviderSdk.builder()
      .registerView(
        selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
        view: View.builder().build()
      )
      .registerMetricReader(
        reader: reader
      )
      .build()

    metrics = .init(meter: provider.meterBuilder(name: "meter").build())
    MetricsSystem.bootstrapInternal(metrics)
  }

  // MARK: - Test Lifecycle

  func testDestroy() {
    let handler = metrics.makeCounter(label: "my_label", dimensions: [])
    XCTAssertEqual(metrics.metrics.count, 1)
    handler.increment(by: 1)
    waitForExpectations(timeout: 10, handler: nil)
    metrics.destroyCounter(handler)
    XCTAssertEqual(metrics.metrics.count, 0)
  }

  // MARK: - Test Metric: Counter

  func testCounter() throws {
    let counter = Counter(label: "my_counter")
    counter.increment()

    waitForExpectations(timeout: 10, handler: nil)

    let metric = stableMetrics[0]
    let data = try XCTUnwrap(metric.data.points.last as? LongPointData)
    XCTAssertEqual(metric.name, "my_counter")
    XCTAssertEqual(metric.type, .LongSum)
    XCTAssertEqual(data.value, 1)
    XCTAssertNil(data.attributes["label_one"])
  }

  func testCounter_withLabels() throws {
    let counter = Counter(label: "my_counter", dimensions: [("label_one", "value")])
    counter.increment(by: 5)

    waitForExpectations(timeout: 10, handler: nil)

    let metric = stableMetrics[0]
    let data = try XCTUnwrap(metric.data.points.last as? LongPointData)
    XCTAssertEqual(metric.name, "my_counter")
    XCTAssertEqual(metric.type, .LongSum)
    XCTAssertEqual(data.value, 5)
    XCTAssertEqual(data.attributes["label_one"]?.description, "value")
  }

  // MARK: - Test Metric: Gauge

  func testGauge() throws {
    let gauge = Gauge(label: "my_gauge")
    gauge.record(100)

    waitForExpectations(timeout: 10, handler: nil)

    let metric = stableMetrics[0]
    let data = try XCTUnwrap(metric.data.points.last as? DoublePointData)
    XCTAssertEqual(metric.name, "my_gauge")
    XCTAssertEqual(metric.type, .DoubleGauge)
    XCTAssertEqual(data.value, 100)
    XCTAssertNil(data.attributes["label_one"])
  }

  // MARK: - Test Metric: Histogram

  func testHistogram() throws {
    let histogram = Gauge(label: "my_histogram", dimensions: [], aggregate: true)
    histogram.record(100)

    waitForExpectations(timeout: 10, handler: nil)

    let metric = stableMetrics[0]
    let data = try XCTUnwrap(metric.data.points.last as? HistogramPointData)
    XCTAssertEqual(metric.name, "my_histogram")
    XCTAssertEqual(metric.type, .Histogram)
//    XCTAssertEqual(/*data*/., 100)
    XCTAssertNil(data.attributes["label_one"])
  }

  // MARK: - Test Metric: Summary

  func testSummary() throws {
    let timer = CoreMetrics.Timer(label: "my_timer")
    timer.recordSeconds(1)

    waitForExpectations(timeout: 10, handler: nil)

    let metric = stableMetrics[0]
    let data = try XCTUnwrap(metric.data.points.last as? DoublePointData)
    XCTAssertEqual(metric.name, "my_timer")
    XCTAssertEqual(metric.type, .DoubleSum)
    XCTAssertEqual(data.value, 1000000000)
    XCTAssertNil(data.attributes["label_one"])
  }

  // MARK: - Test Concurrency

  func testConcurrency() throws {
    DispatchQueue.concurrentPerform(iterations: 5) { _ in
      let counter = Counter(label: "my_counter")
      counter.increment()
    }

    waitForExpectations(timeout: 10, handler: nil)

    let metric = stableMetrics[0]
    let data = try XCTUnwrap(metric.data.points.last as? LongPointData)
    XCTAssertEqual(metric.name, "my_counter")
    XCTAssertEqual(metric.type, .LongSum)
    XCTAssertEqual(data.value, 5)
    XCTAssertNil(data.attributes["label_one"])
  }
}

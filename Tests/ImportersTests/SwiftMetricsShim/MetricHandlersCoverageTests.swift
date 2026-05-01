/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import SwiftMetricsShim
import XCTest

final class MetricHandlersCoverageTests: XCTestCase {
  private func makeMeter() -> any OpenTelemetryApi.Meter {
    let provider = MeterProviderSdk.builder().build()
    return provider.meterBuilder(name: "test-meter").build()
  }

  func testSwiftCounterMetricIncrementDoesNotCrash() {
    let handler = SwiftCounterMetric(name: "c1", labels: ["k": "v"], meter: makeMeter())
    handler.increment(by: 3)
    handler.reset()
    XCTAssertEqual(handler.metricName, "c1")
    XCTAssertEqual(handler.metricType, .counter)
    XCTAssertEqual(handler.labels["k"], .string("v"))
  }

  func testSwiftGaugeRecordsIntAndDouble() {
    let handler = SwiftGaugeMetric(name: "g1", labels: ["k": "v"], meter: makeMeter())
    handler.record(Int64(5))
    handler.record(Double(1.5))
    XCTAssertEqual(handler.metricName, "g1")
    XCTAssertEqual(handler.metricType, .gauge)
  }

  func testSwiftHistogramRecordsIntAndDouble() {
    let handler = SwiftHistogramMetric(name: "h1", labels: ["k": "v"], meter: makeMeter())
    handler.record(Int64(7))
    handler.record(Double(2.5))
    XCTAssertEqual(handler.metricName, "h1")
    XCTAssertEqual(handler.metricType, .histogram)
  }

  func testSwiftSummaryRecordsDuration() {
    let handler = SwiftSummaryMetric(name: "s1", labels: ["k": "v"], meter: makeMeter())
    handler.recordNanoseconds(1_000_000)
    XCTAssertEqual(handler.metricName, "s1")
    XCTAssertEqual(handler.metricType, .summary)
  }

  func testMetricTypeRawValues() {
    XCTAssertEqual(MetricType.counter.rawValue, "counter")
    XCTAssertEqual(MetricType.histogram.rawValue, "histogram")
    XCTAssertEqual(MetricType.gauge.rawValue, "gauge")
    XCTAssertEqual(MetricType.summary.rawValue, "summary")
  }

  func testMetricKeyHashableEqualityAndInequality() {
    let a = MetricKey(name: "m", type: .counter)
    let b = MetricKey(name: "m", type: .counter)
    let c = MetricKey(name: "m", type: .gauge)
    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, c)
    XCTAssertEqual(a.hashValue, b.hashValue)
  }
}

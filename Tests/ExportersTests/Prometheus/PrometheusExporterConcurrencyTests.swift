/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
@testable import PrometheusExporter
import SharedTestUtils
import XCTest

/// Stress tests for the Prometheus exporter. The HTTP server is not started;
/// scrapes are simulated by calling the same collection writer the handler
/// uses. They only run under Thread Sanitizer (or `OTEL_CONCURRENCY_TESTS=1`).
final class PrometheusExporterConcurrencyTests: XCTestCase {
  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
  }

  private func makeExporter() -> UncheckedSendable<PrometheusExporter> {
    UncheckedSendable(PrometheusExporter(options: PrometheusExporterOptions(url: "http://localhost:9184/metrics/")))
  }

  func testExportRacesScrapes() {
    let exporter = makeExporter()
    let tornReads = ConcurrentCounter()
    let scrapes = ConcurrentCounter()
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 100

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
      if thread.isMultiple(of: 2) {
        // Each exporting thread publishes a batch whose size identifies it.
        let batch = (0 ... thread).map { TelemetryFixtures.metricData(name: "metric_\(thread)_\($0)", value: Double($0)) }
        _ = exporter.value.export(metrics: batch)
      } else {
        let snapshot = exporter.value.getMetrics()
        // A snapshot must be a whole batch: empty, or sized like one exporter's batch.
        if !snapshot.isEmpty, !(1 ... threads).contains(snapshot.count) {
          tornReads.increment()
        }
        let output = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter.value)
        if !output.isEmpty {
          scrapes.increment()
        }
      }
    }

    XCTAssertEqual(tornReads.value, 0)
    XCTAssertGreaterThan(scrapes.value, 0)
  }

  func testFlushAndShutdownRaceExport() {
    let exporter = makeExporter()

    ConcurrencyTesting.concurrently([
      { _ = exporter.value.export(metrics: [TelemetryFixtures.metricData()]) },
      { _ = exporter.value.flush() },
      { _ = exporter.value.shutdown() },
      { _ = exporter.value.getMetrics() },
      { _ = exporter.value.getAggregationTemporality(for: .counter) }
    ])
  }
}

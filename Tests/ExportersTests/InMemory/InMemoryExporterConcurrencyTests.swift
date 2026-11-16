/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import SharedTestUtils
import XCTest

/// Stress tests for the in-memory span exporter. They only run under Thread
/// Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class InMemoryExporterConcurrencyTests: XCTestCase {
  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
  }

  func testExportAndReadFromManyThreads() {
    let exporter = InMemoryExporter()
    let successes = ConcurrentCounter()
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
      if thread == 0 {
        _ = exporter.getFinishedSpanItems()
        _ = exporter.flush()
      } else if exporter.export(spans: [TelemetryFixtures.spanData(name: "thread-\(thread)")]) == .success {
        successes.increment()
      }
    }

    XCTAssertEqual(successes.value, (threads - 1) * iterations)
    XCTAssertEqual(exporter.getFinishedSpanItems().count, successes.value)
  }

  func testResetRacesExport() {
    let exporter = InMemoryExporter()

    ConcurrencyTesting.stress { thread, _ in
      if thread.isMultiple(of: 4) {
        exporter.reset()
      } else {
        _ = exporter.export(spans: [TelemetryFixtures.spanData()])
        _ = exporter.getFinishedSpanItems()
      }
    }

    exporter.reset()
    XCTAssertTrue(exporter.getFinishedSpanItems().isEmpty)
  }

  func testShutdownRacesExport() {
    let exporter = InMemoryExporter()
    let failuresAfterShutdown = ConcurrentCounter()

    ConcurrencyTesting.concurrently([
      { exporter.shutdown() },
      { _ = exporter.export(spans: [TelemetryFixtures.spanData()]) },
      { _ = exporter.export(spans: [TelemetryFixtures.spanData()]) },
      { _ = exporter.flush() },
      { _ = exporter.getFinishedSpanItems() }
    ])

    ConcurrencyTesting.stress(threads: 4, iterations: 20) { _, _ in
      if exporter.export(spans: [TelemetryFixtures.spanData()]) == .failure {
        failuresAfterShutdown.increment()
      }
    }

    XCTAssertEqual(failuresAfterShutdown.value, 80)
    XCTAssertTrue(exporter.getFinishedSpanItems().isEmpty)
  }
}

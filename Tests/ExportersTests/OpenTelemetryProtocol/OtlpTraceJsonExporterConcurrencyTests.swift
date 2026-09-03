/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterGrpc
import OpenTelemetrySdk
import SharedTestUtils
import XCTest

/// Stress tests for the JSON trace exporter. They only run under Thread
/// Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class OtlpTraceJsonExporterConcurrencyTests: XCTestCase {
  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
  }

  func testExportAndReadFromManyThreads() {
    let exporter = OtlpTraceJsonExporter()
    let successes = ConcurrentCounter()
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
      if thread == 0 {
        _ = exporter.getExportedSpans()
        _ = exporter.flush()
      } else if exporter.export(spans: [TelemetryFixtures.spanData(name: "thread-\(thread)")]) == .success {
        successes.increment()
      }
    }

    XCTAssertEqual(successes.value, (threads - 1) * iterations)
    XCTAssertEqual(exporter.getExportedSpans().count, successes.value)
  }

  func testResetAndShutdownRaceExport() {
    let exporter = OtlpTraceJsonExporter()

    ConcurrencyTesting.stress(threads: 8, iterations: 30) { thread, iteration in
      switch thread {
      case 0:
        exporter.reset()
      case 1 where iteration == 29:
        exporter.shutdown()
      default:
        _ = exporter.export(spans: [TelemetryFixtures.spanData()])
        _ = exporter.getExportedSpans()
      }
    }

    XCTAssertEqual(exporter.flush(), .failure)
    XCTAssertEqual(exporter.export(spans: [TelemetryFixtures.spanData()]), .failure)
    XCTAssertTrue(exporter.getExportedSpans().isEmpty)
  }
}

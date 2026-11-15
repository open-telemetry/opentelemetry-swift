/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(watchOS) && !os(visionOS)

  import Foundation
  @testable import JaegerExporter
  import OpenTelemetryApi
  import OpenTelemetrySdk
  import SharedTestUtils
  import XCTest

  /// Stress tests for the Jaeger exporter. Batches go out over UDP to the
  /// loopback address, which needs no listener. They only run under Thread
  /// Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
  final class JaegerExporterConcurrencyTests: XCTestCase {
    override func setUpWithError() throws {
      try ConcurrencyTesting.skipUnlessEnabled()
    }

    func testAdapterConvertsSpansFromManyThreads() {
      let converted = ConcurrentCounter()

      ConcurrencyTesting.stress { thread, iteration in
        let spans = [
          TelemetryFixtures.spanData(name: "span-\(thread)-\(iteration)", kind: .client, attributes: ["thread": .int(thread)]),
          TelemetryFixtures.spanData(name: "error", status: .error(description: "boom"))
        ]
        converted.increment(by: Adapter.toJaeger(spans: spans).count)
      }

      XCTAssertEqual(converted.value, 2 * ConcurrencyTesting.defaultThreads * ConcurrencyTesting.defaultIterations)
    }

    func testExportsThroughSharedExporterFromManyThreads() {
      let exporter = JaegerSpanExporter(serviceName: "stress", collectorAddress: "127.0.0.1")
      let attempts = ConcurrentCounter()

      ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 25) { thread, iteration in
        _ = exporter.export(spans: [TelemetryFixtures.spanData(name: "span-\(thread)-\(iteration)")])
        _ = exporter.flush()
        attempts.increment()
      }

      exporter.shutdown()
      XCTAssertEqual(attempts.value, ConcurrencyTesting.defaultThreads * 25)
    }
  }

#endif

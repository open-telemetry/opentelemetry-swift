/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import SharedTestUtils
@testable import URLSessionInstrumentation
import XCTest

/// Stress tests for URLSession instrumentation. The swizzling is installed
/// once per process by `URLSessionInstrumentationTests`, and only the first
/// instance's configuration is applied, so these live on that class and swap
/// its configuration for the duration of each test. They only run under
/// Thread Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
extension URLSessionInstrumentationTests {
  private final class Counters: @unchecked Sendable {
    let created = ConcurrentCounter()
    let responses = ConcurrentCounter()
    let errors = ConcurrentCounter()
    let named = ConcurrentCounter()
  }

  private static func toggleSemanticConvention(on instrumentation: URLSessionInstrumentation, iteration: Int) {
    var updated = instrumentation.configuration
    updated.semanticConvention = iteration.isMultiple(of: 2) ? .old : .stable
    instrumentation.configuration = updated
    _ = instrumentation.configuration.shouldInstrument
  }

  private func withStressConfiguration(_ counters: Counters, _ body: (URLSessionInstrumentation) -> Void) {
    let instrumentation = URLSessionInstrumentationTests.instrumentation!
    let original = instrumentation.configuration
    instrumentation.configuration = URLSessionInstrumentationConfiguration(
      shouldInstrument: { _ in true },
      nameSpan: { request in
        counters.named.increment()
        return "stress \(request.url?.path ?? "")"
      },
      shouldInjectTracingHeaders: { _ in true },
      createdRequest: { _, _ in counters.created.increment() },
      receivedResponse: { _, _, _ in counters.responses.increment() },
      receivedError: { _, _, _, _ in counters.errors.increment() }
    )
    defer { instrumentation.configuration = original }
    body(instrumentation)
  }

  func testConcurrentDataTasksThroughSharedInstrumentation() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    let counters = Counters()
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 15

    withStressConfiguration(counters) { instrumentation in
      let inFlight = DispatchGroup()

      ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
        inFlight.enter()
        var request = URLRequest(url: URL(string: "http://localhost:33333/success?thread=\(thread)&iteration=\(iteration)")!)
        request.timeoutInterval = 30
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
          inFlight.leave()
        }
        task.resume()
        _ = instrumentation.startedRequestSpans
      }

      XCTAssertEqual(inFlight.wait(timeout: .now() + 120), .success)
      wait(timeout: 10) { instrumentation.startedRequestSpans.isEmpty }
    }

    XCTAssertEqual(counters.created.value, threads * iterations)
    XCTAssertEqual(counters.named.value, threads * iterations)
    XCTAssertEqual(counters.responses.value + counters.errors.value, threads * iterations)
    XCTAssertTrue(URLSessionInstrumentationTests.instrumentation.startedRequestSpans.isEmpty)
  }

  func testConfigurationUpdatesRaceInFlightRequests() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    let counters = Counters()

    withStressConfiguration(counters) { instrumentation in
      let inFlight = DispatchGroup()

      ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 10) { thread, iteration in
        if thread == 0 {
          // Reader and writer of the configuration on different threads.
          Self.toggleSemanticConvention(on: instrumentation, iteration: iteration)
        } else {
          inFlight.enter()
          let url = URL(string: "http://localhost:33333/success?config=\(thread)-\(iteration)")!
          let task = URLSession.shared.dataTask(with: url) { _, _, _ in
            inFlight.leave()
          }
          task.resume()
        }
      }

      XCTAssertEqual(inFlight.wait(timeout: .now() + 120), .success)
      wait(timeout: 10) { instrumentation.startedRequestSpans.isEmpty }
    }

    XCTAssertEqual(counters.created.value, (ConcurrencyTesting.defaultThreads - 1) * 10)
  }
}

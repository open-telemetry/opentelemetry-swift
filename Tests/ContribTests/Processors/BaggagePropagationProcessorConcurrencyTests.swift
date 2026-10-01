/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import BaggagePropagationProcessor
import InMemoryExporter
@testable import OpenTelemetryApi
import OpenTelemetrySdk
import SharedTestUtils
import XCTest

/// Stress tests for the baggage propagation span processor. They only run
/// under Thread Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class BaggagePropagationProcessorConcurrencyTests: XCTestCase {
  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
  }

  private func makeBaggage(_ entries: [String: String]) throws -> Baggage {
    var builder = DefaultBaggageManager.instance.baggageBuilder()
    for (key, value) in entries {
      let entryKey = try XCTUnwrap(EntryKey(name: key))
      let entryValue = try XCTUnwrap(EntryValue(string: value))
      builder = builder.put(key: entryKey, value: entryValue, metadata: nil)
    }
    return builder.build()
  }

  func testSpansStartedFromManyThreadsReceiveFilteredBaggage() throws {
    let baggage = try makeBaggage(["keepme": "kept", "dropme": "dropped"])
    var processor = BaggagePropagationProcessor(filter: { $0.key.name == "keepme" })
    processor.activeBaggage = { baggage }
    let exporter = InMemoryExporter()
    let provider = TracerProviderBuilder()
      .add(spanProcessor: processor)
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
      .build()
    let tracer = UncheckedSendable(provider.get(instrumentationName: "stress"))
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      let span = tracer.value.spanBuilder(spanName: "span-\(thread)-\(iteration)").startSpan()
      span.setAttribute(key: "thread", value: thread)
      span.end()
    }

    // SimpleSpanProcessor exports asynchronously.
    provider.forceFlush()
    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, threads * iterations)
    XCTAssertTrue(spans.allSatisfy { $0.attributes["keepme"] == .string("kept") })
    XCTAssertTrue(spans.allSatisfy { $0.attributes["dropme"] == nil })
  }

  func testProcessorReadsPerThreadActiveBaggageThroughContextProvider() throws {
    // Uses the processor's default `activeBaggage`, which reads the global
    // context provider, so every thread installs its own baggage first.
    let processor = BaggagePropagationProcessor(filter: { _ in true })
    let exporter = InMemoryExporter()
    let provider = TracerProviderBuilder()
      .add(spanProcessor: processor)
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
      .build()
    let tracer = UncheckedSendable(provider.get(instrumentationName: "stress"))
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50
    let baggages = try UncheckedSendable((0 ..< threads).map { try makeBaggage(["thread": "\($0)"]) })

    OpenTelemetry.withContextManager(ThreadLocalContextManager()) {
      ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
        let baggage = baggages.value[thread]
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
        let span = tracer.value.spanBuilder(spanName: "span-\(thread)").startSpan()
        span.setAttribute(key: "expected", value: "\(thread)")
        span.end()
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage)
      }
    }

    provider.forceFlush()
    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, threads * iterations)
    let mismatched = spans.filter { $0.attributes["thread"] != $0.attributes["expected"] }
    XCTAssertTrue(mismatched.isEmpty, "\(mismatched.count) spans carried another thread's baggage")
  }
}

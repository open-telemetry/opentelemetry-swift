/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import OTelSwiftTracing
import SharedTestUtils
import Tracing
import XCTest

/// Stress tests for the swift-distributed-tracing bridge. They only run under
/// Thread Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class OTelSwiftTracingConcurrencyTests: XCTestCase {
  private var exporter: InMemoryExporter!
  private var processor: SimpleSpanProcessor!
  private var tracer: OTelTracer!

  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    exporter = InMemoryExporter()
    processor = SimpleSpanProcessor(spanExporter: exporter)
    let provider = TracerProviderSdk(spanProcessors: [processor])
    tracer = OTelTracer(tracerProvider: provider, propagator: W3CTraceContextPropagator())
  }

  override func tearDown() {
    exporter?.shutdown()
    exporter = nil
    processor = nil
    tracer = nil
  }

  func testStartAndEndSpansFromManyThreads() {
    let tracer = self.tracer!
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      tracer.withSpan("span-\(thread)") { span in
        span.attributes["thread"] = thread
        span.attributes["iteration"] = iteration
        span.addEvent(SpanEvent(name: "event"))
        span.setStatus(SpanStatus(code: .ok))
        _ = span.isRecording
      }
    }

    _ = processor.forceFlush()
    XCTAssertEqual(exporter.getFinishedSpanItems().count, threads * iterations)
  }

  func testMutateSharedSpanFromManyThreads() {
    let span = tracer.startSpan("shared")
    let threads = ConcurrencyTesting.defaultThreads

    ConcurrencyTesting.stress(threads: threads) { thread, iteration in
      span.attributes["thread-\(thread)"] = iteration
      span.operationName = "renamed-\(thread)"
      span.setStatus(SpanStatus(code: iteration.isMultiple(of: 2) ? .ok : .error))
      span.addEvent(SpanEvent(name: "event-\(thread)"))
      span.recordError(StressError.boom, attributes: ["thread": .int64(Int64(thread))])
      _ = span.attributes
      _ = span.operationName
      _ = span.isRecording
    }

    span.end()
    _ = processor.forceFlush()
    let finished = exporter.getFinishedSpanItems()
    XCTAssertEqual(finished.count, 1)
    XCTAssertEqual(finished.first?.attributes.count, threads)
  }

  func testEndRacesAttributeWritesAndEvents() {
    let span = tracer.startSpan("racing-end")

    ConcurrencyTesting.concurrently([
      { span.end() },
      { span.attributes = ["after": "end"] },
      { span.addEvent(SpanEvent(name: "late")) },
      { span.setStatus(SpanStatus(code: .error)) },
      { span.operationName = "renamed" },
      { _ = span.attributes }
    ])

    _ = processor.forceFlush()
    XCTAssertEqual(exporter.getFinishedSpanItems().count, 1)
  }

  func testInjectAndExtractFromManyThreads() {
    let tracer = self.tracer!
    let parent = tracer.startSpan("parent")
    defer { parent.end() }
    let parentContext = parent.context
    let expectedTraceId = parentContext.otelSpanContext?.traceId
    let mismatches = ConcurrentCounter()

    ConcurrencyTesting.stress { _, _ in
      var carrier: [String: String] = [:]
      tracer.inject(parentContext, into: &carrier, using: DictionaryInjector())

      var extracted = ServiceContext.topLevel
      tracer.extract(carrier, into: &extracted, using: DictionaryExtractor())
      if extracted.otelSpanContext?.traceId != expectedTraceId {
        mismatches.increment()
      }

      // Children created from the extracted context on many threads.
      tracer.withSpan("child", context: extracted) { child in
        child.attributes["child"] = true
      }
    }

    XCTAssertEqual(mismatches.value, 0)
  }
}

private enum StressError: Error {
  case boom
}

private struct DictionaryInjector: Injector {
  func inject(_ value: String, forKey key: String, into carrier: inout [String: String]) {
    carrier[key] = value
  }
}

private struct DictionaryExtractor: Extractor {
  func extract(key: String, from carrier: [String: String]) -> String? {
    carrier[key]
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import OpenTracingShim
import Opentracing
import SharedTestUtils
import XCTest

/// Stress tests for the OpenTracing shim. They only run under Thread
/// Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class OpenTracingShimConcurrencyTests: XCTestCase {
  private var tracerProvider: TracerProviderSdk!
  private var tracer: Tracer!
  private var telemetryInfo: TelemetryInfo!
  private var tracerShim: TracerShim!

  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    tracerProvider = TracerProviderSdk()
    tracer = tracerProvider.get(instrumentationName: "OpenTracingShimConcurrencyTests")
    telemetryInfo = TelemetryInfo(tracer: tracer,
                                  baggageManager: OpenTelemetry.instance.baggageManager,
                                  propagators: OpenTelemetry.instance.propagators)
    tracerShim = TracerShim(telemetryInfo: telemetryInfo)
  }

  override func tearDown() {
    tracerShim = nil
    telemetryInfo = nil
    tracer = nil
    tracerProvider = nil
  }

  func testContextForSharedSpanResolvesToOneShimFromManyThreads() {
    let span = tracer.spanBuilder(spanName: "shared").startSpan()
    defer { span.end() }
    let spanShim = UncheckedSendable(SpanShim(telemetryInfo: telemetryInfo, span: span))
    let contexts = ConcurrentCollector<ObjectIdentifier>()

    ConcurrencyTesting.stress { _, _ in
      let context = spanShim.value.context() as AnyObject
      contexts.append(ObjectIdentifier(context))
    }

    XCTAssertEqual(Set(contexts.values).count, 1)
  }

  func testBaggageOnSharedSpanFromManyThreads() {
    let span = tracer.spanBuilder(spanName: "baggage").startSpan()
    defer { span.end() }
    let spanShim = UncheckedSendable(SpanShim(telemetryInfo: telemetryInfo, span: span))
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations
    let missing = ConcurrentCounter()

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      _ = spanShim.value.setBaggageItem("thread-\(thread)", value: "\(iteration)")
      if spanShim.value.getBaggageItem("thread-\(thread)") == nil {
        missing.increment()
      }
      _ = spanShim.value.context()
    }

    XCTAssertEqual(missing.value, 0)
    for thread in 0 ..< threads {
      XCTAssertEqual(spanShim.value.getBaggageItem("thread-\(thread)"), "\(iterations - 1)")
    }
  }

  func testStartTagLogFinishSpansFromManyThreads() {
    let tracerShim = UncheckedSendable(self.tracerShim!)
    let parent = tracerShim.value.startSpan("parent")
    defer { parent.finish() }
    let parentContext = UncheckedSendable(parent.context())

    ConcurrencyTesting.stress { thread, iteration in
      let span = tracerShim.value.startSpan("child-\(thread)",
                                            childOf: parentContext.value,
                                            tags: ["thread": thread])
      span.setTag("iteration", numberValue: NSNumber(value: iteration))
      span.setTag("flag", boolValue: iteration.isMultiple(of: 2))
      span.log(["event": "progress" as NSString])
      span.logEvent("named")
      _ = span.setBaggageItem("key", value: "value")
      _ = span.getBaggageItem("key")
      span.setOperationName("renamed-\(thread)")
      span.finish()
    }
  }

  func testInjectAndExtractFromManyThreads() {
    let tracerShim = UncheckedSendable(self.tracerShim!)
    let parent = tracerShim.value.startSpan("parent")
    defer { parent.finish() }
    let parentContext = UncheckedSendable(parent.context())
    let expectedTraceId = (parent.context() as? SpanContextShim)?.context.traceId
    let missingBaggage = ConcurrentCounter()
    let nilExtracts = ConcurrentCounter()
    let wrongTraces = ConcurrentCounter()

    // `extract` refuses to build a context unless the calling thread has
    // active baggage, so each worker installs its own. A thread-local
    // manager keeps that deterministic on plain threads.
    OpenTelemetry.withContextManager(ThreadLocalContextManager()) {
      ConcurrencyTesting.stress { _, _ in
      let baggage = OpenTelemetry.instance.baggageManager.baggageBuilder().build()
      OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
      defer { OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage) }

      if OpenTelemetry.instance.contextProvider.activeBaggage == nil {
        missingBaggage.increment()
      }

      let carrier = NSMutableDictionary()
      _ = tracerShim.value.inject(parentContext.value, format: OTFormatTextMap, carrier: carrier)
      let headers = carrier as? [String: String] ?? [:]
      guard let extracted = tracerShim.value.extract(withFormat: OTFormatTextMap, carrier: headers) as? SpanContextShim else {
        nilExtracts.increment()
        return
      }
      if extracted.context.traceId != expectedTraceId {
        wrongTraces.increment()
      }
      }
    }

    XCTAssertEqual(missingBaggage.value, 0, "active baggage not visible on worker thread")
    XCTAssertEqual(nilExtracts.value, 0, "extract returned nil")
    XCTAssertEqual(wrongTraces.value, 0, "extract returned another trace")
  }

  func testReadWriteLockUnderContention() {
    let lock = UncheckedSendable(OpenTracingShim.ReadWriteLock())
    let writes = ConcurrentCounter()
    nonisolated(unsafe) var guarded = 0

    ConcurrencyTesting.stress { thread, _ in
      if thread.isMultiple(of: 4) {
        lock.value.withWriterLockVoid { guarded += 1 }
        writes.increment()
      } else {
        _ = lock.value.withReaderLock { guarded }
      }
    }

    XCTAssertEqual(guarded, writes.value)
  }
}

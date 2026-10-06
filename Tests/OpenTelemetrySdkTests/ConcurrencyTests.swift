/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(_Concurrency) && canImport(OpenTelemetryConcurrency)
  import OpenTelemetryTestUtils
  import XCTest
  import OpenTelemetrySdk
  import OpenTelemetryApi
  import OpenTelemetryConcurrency

  private typealias OpenTelemetry = OpenTelemetryConcurrency.OpenTelemetry

  final class ConcurrencyTests: OpenTelemetryContextTestCase {
    var oldTracerProvider: TracerProvider?

    var tracer: TracerWrapper {
      OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ConcurrencyTests", instrumentationVersion: nil)
    }

    override func setUp() async throws {
      try await super.setUp()
      oldTracerProvider = OpenTelemetry.instance.tracerProvider.inner
      OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderSdk())
    }

    override func tearDown() async throws {
      OpenTelemetry.registerTracerProvider(tracerProvider: oldTracerProvider!)
      try await super.tearDown()
    }

    func testBasicSpan() {
      // Attempting to use `setActive` here will cause a build error since we're using `OpenTelemetryConcurrency.OpenTelemetry` instead of `OpenTelemetryApi.OpenTelemetry`
      tracer
        .spanBuilder(spanName: "basic")
        .withActiveSpan { span in
          XCTAssertIdentical(OpenTelemetry.instance.contextProvider.activeSpan, span)
        }

      XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }

    func testDetachedTask() async {
      await tracer
        .spanBuilder(spanName: "basic")
        .withActiveSpan { _ in
          let testTracer = self.tracer
          await Task.detached {
            // Detached task doesn't inherit context
            XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
            let detached = testTracer.spanBuilder(spanName: "detached").startSpan()
            XCTAssertNil((detached as! SpanSdk).parentContext)
          }.value
        }
    }

    nonisolated func testTask() async {
      await tracer
        .spanBuilder(spanName: "basic")
        .withActiveSpan { span in
          let testTracer = self.tracer
          XCTAssertIdentical(OpenTelemetry.instance.contextProvider.activeSpan, span)
          let attached = testTracer.spanBuilder(spanName: "attached").startSpan()
          XCTAssertEqual((attached as! SpanSdk).parentContext, (span as! SpanSdk).context)
        }
    }
  }

#endif

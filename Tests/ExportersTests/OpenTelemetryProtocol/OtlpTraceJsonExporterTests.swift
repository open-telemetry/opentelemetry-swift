/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

@testable import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterGrpc
@testable import OpenTelemetrySdk
import XCTest

final class OtlpTraceJsonExporterTests: XCTestCase {
  // MARK: - Variable Declaration

  private var tracerSdkFactory = TracerProviderSdk()
  private var spanProcessor: SpanProcessor!
  private var tracer: Tracer!
  private var exporter: OtlpTraceJsonExporter!

  // MARK: - setUp()

  override func setUp() {
    exporter = OtlpTraceJsonExporter()
    spanProcessor = SimpleSpanProcessor(spanExporter: exporter)
    tracerSdkFactory.addSpanProcessor(spanProcessor)
    tracer = tracerSdkFactory.get(instrumentationName: "OtlpTraceJsonExporterTests")
  }

  // MARK: - Unit Tests

  func testGetExportedSpans() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()
    spanProcessor.forceFlush()

    let spans = exporter.getExportedSpans()
    XCTAssertEqual(spans.count, 3)

    let firstSpan = spans[0].resourceSpans?[0].scopeSpans?[0].spans
    XCTAssertEqual(firstSpan?[0].name, "one")

    let secondSpan = spans[1].resourceSpans?[0].scopeSpans?[0].spans
    XCTAssertEqual(secondSpan?[0].name, "two")

    let thirdSpan = spans[2].resourceSpans?[0].scopeSpans?[0].spans
    XCTAssertEqual(thirdSpan?[0].name, "three")
  }

  func testResetClearsFinishedSpans() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()
    spanProcessor.forceFlush()

    var spans = exporter.getExportedSpans()
    XCTAssertEqual(spans.count, 3)

    exporter.reset()
    spans = exporter.getExportedSpans()
    XCTAssertEqual(spans.count, 0)
  }

  func testResetDoesNotRestartAfterShutdown() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    spanProcessor.forceFlush()

    exporter.shutdown()
    exporter.reset()

    XCTAssertEqual(exporter.export(spans: []), .failure)
  }

  func testShutdownClearsFinishedSpans() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()
    spanProcessor.forceFlush()

    exporter.shutdown()

    let traces = exporter.getExportedSpans()
    XCTAssertEqual(traces.count, 0)
  }

  func testShutdownStopsFurtherExports() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()
    spanProcessor.forceFlush()

    exporter.shutdown()
    tracer.spanBuilder(spanName: "four").startSpan().end()
    spanProcessor.forceFlush()

    let spans = exporter.getExportedSpans()
    XCTAssertEqual(spans.count, 0)
  }

  func testExportReturnsSuccessWhenStarted() {
    XCTAssertEqual(exporter.export(spans: []), .success)
  }

  func testExportReturnsFailureWhenStopped() {
    exporter.shutdown()
    XCTAssertEqual(exporter.export(spans: []), .failure)
  }

  func testFlushReturnsSuccessWhenRunning() {
    XCTAssertEqual(exporter.flush(), .success)
  }

  func testFlushReturnsFailiureWhenStopped() {
    exporter.shutdown()
    XCTAssertEqual(exporter.flush(), .failure)
  }
}

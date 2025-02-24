/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

@testable import InMemoryExporter
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class InMemoryExporterTests: XCTestCase {
  private var tracerSdkFactory = TracerProviderSdk()
  private var spanProcessor: SpanProcessor!
  private var tracer: Tracer!
  private var exporter: InMemoryExporter!

  override func setUp() {
    exporter = InMemoryExporter()
    spanProcessor = SimpleSpanProcessor(spanExporter: exporter)
    tracerSdkFactory.addSpanProcessor(spanProcessor)
    tracer = tracerSdkFactory.get(instrumentationName: "InMemoryExporterTests")
  }

  func testGetFinishedSpanItems() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()
    spanProcessor.forceFlush()

    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 3)
    XCTAssertEqual(spans[0].name, "one")
    XCTAssertEqual(spans[1].name, "two")
    XCTAssertEqual(spans[2].name, "three")
  }

  func testResetClearsFinishedSpans() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()
    spanProcessor.forceFlush()

    var spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 3)

    exporter.reset()
    spans = exporter.getFinishedSpanItems()
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

    let spans = exporter.getFinishedSpanItems()
    XCTAssertEqual(spans.count, 0)
  }

  func testShutdownStopsFurtherExports() {
    tracer.spanBuilder(spanName: "one").startSpan().end()
    tracer.spanBuilder(spanName: "two").startSpan().end()
    tracer.spanBuilder(spanName: "three").startSpan().end()
    spanProcessor.forceFlush()

    exporter.shutdown()
    tracer.spanBuilder(spanName: "four").startSpan().end()

    let spans = exporter.getFinishedSpanItems()
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

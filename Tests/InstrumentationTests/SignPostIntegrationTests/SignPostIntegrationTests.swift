/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import os
import OpenTelemetrySdk
import InMemoryExporter
import SignPostIntegration
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
  import MetricKit
#endif

@available(iOS 15.0, macOS 12, tvOS 15.0, watchOS 8.0, *)
final class SignPostIntegrationTests: XCTestCase {
  private let customLog = OSLog(subsystem: "io.opentelemetry.signpost.tests", category: "CustomSpans")

  func testSignposterDefaultLog() {
    let processor = OSSignposterIntegration()
    let defaultLog = OSLog(subsystem: "OpenTelemetry", category: .pointsOfInterest)

    XCTAssertEqual(processor.osSignposter.isEnabled, defaultLog.signpostsEnabled)
    assertSpanExport(processor, name: "signpost.default.modern")
  }

  func testSignposterCustomLog() {
    let processor = OSSignposterIntegration(log: customLog)

    XCTAssertEqual(processor.osSignposter.isEnabled, customLog.signpostsEnabled)
    assertSpanExport(processor, name: "signpost.custom.modern")
  }

  func testSignposterDisabledLog() {
    let processor = OSSignposterIntegration(log: .disabled)

    XCTAssertFalse(processor.osSignposter.isEnabled)
    assertSpanExport(processor, name: "signpost.disabled.modern")
  }

  #if !os(watchOS) && !os(visionOS)
    func testLegacyDefaultLog() {
      let processor = SignPostIntegration()
      let defaultLog = OSLog(subsystem: "OpenTelemetry", category: .pointsOfInterest)

      XCTAssertTrue(processor.osLog === defaultLog)
      XCTAssertEqual(processor.osLog.signpostsEnabled, defaultLog.signpostsEnabled)
      assertSpanExport(processor, name: "signpost.default.legacy")
    }

    func testLegacyCustomLog() {
      let processor = SignPostIntegration(log: customLog)

      XCTAssertTrue(processor.osLog === customLog)
      assertSpanExport(processor, name: "signpost.custom.legacy")
    }

    func testLegacyDisabledLog() {
      let processor = SignPostIntegration(log: .disabled)

      XCTAssertTrue(processor.osLog === OSLog.disabled)
      XCTAssertFalse(processor.osLog.signpostsEnabled)
      assertSpanExport(processor, name: "signpost.disabled.legacy")
    }
  #endif

  #if os(iOS) || os(macOS) || os(visionOS)
    func testSignposterMetricKitLog() {
      let log = MXMetricManager.makeLogHandle(category: "OpenTelemetrySpans")
      let processor = OSSignposterIntegration(log: log)

      XCTAssertEqual(processor.osSignposter.isEnabled, log.signpostsEnabled)
      assertSpanExport(processor, name: "signpost.metrickit.modern")
    }

    #if !os(visionOS)
      func testLegacyMetricKitLog() {
        let log = MXMetricManager.makeLogHandle(category: "OpenTelemetrySpans")
        let processor = SignPostIntegration(log: log)

        XCTAssertTrue(processor.osLog === log)
        assertSpanExport(processor, name: "signpost.metrickit.legacy")
      }
    #endif
  #endif

  private func assertSpanExport(_ processor: SpanProcessor, name: String,
                                file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(processor.isStartRequired, file: file, line: line)
    XCTAssertTrue(processor.isEndRequired, file: file, line: line)

    let exporter = InMemoryExporter()
    let provider = TracerProviderSdk()
    provider.addSpanProcessor(processor)
    provider.addSpanProcessor(SimpleSpanProcessor(spanExporter: exporter))
    defer { provider.shutdown() }

    let span = provider.get(instrumentationName: "SignPostIntegrationTests")
      .spanBuilder(spanName: name).startSpan()
    XCTAssertTrue(exporter.getFinishedSpanItems().isEmpty, file: file, line: line)
    span.end()
    provider.forceFlush()

    let exportedSpans = exporter.getFinishedSpanItems()
    XCTAssertEqual(exportedSpans.count, 1, file: file, line: line)
    XCTAssertEqual(exportedSpans.first?.name, name, file: file, line: line)
    XCTAssertEqual(exportedSpans.first?.spanId, span.context.spanId, file: file, line: line)
  }
}

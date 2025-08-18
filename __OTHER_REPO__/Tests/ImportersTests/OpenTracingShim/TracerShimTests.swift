/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import Opentracing
@testable import OpenTracingShim
import XCTest

class TracerShimTests: XCTestCase {
  let tracerProviderSdk = TracerProviderSdk()
  var tracer: Tracer!
  var telemetryInfo: TelemetryInfo!
  var tracerShim: TracerShim!

  override func setUp() {
    tracer = tracerProviderSdk.get(instrumentationName: "SpanShimTest")
    let telemetryInfo = TelemetryInfo(tracer: tracer, baggageManager: OpenTelemetry.instance.baggageManager, propagators: OpenTelemetry.instance.propagators)
    tracerShim = TracerShim(telemetryInfo: telemetryInfo)
  }

  func testDefaultTracer() {
    _ = tracerShim.startSpan("one")
    XCTAssertNotNil(OpenTelemetry.instance.contextProvider.activeSpan)
  }

  func testActiveSpan() {
    let otSpan = tracerShim.startSpan("one") as! SpanShim
    XCTAssertNotNil(OpenTelemetry.instance.contextProvider.activeSpan)
    otSpan.finish()
  }

  func testExtractNullContext() {
    let result = tracerShim.extract(withFormat: OTFormatTextMap, carrier: [String: String]())
    XCTAssertNil(result)
  }

  func testInjecttNullContext() {
    let otSpan = tracerShim.startSpan("one") as! SpanShim
    let map = [String: String]()
    _ = tracerShim.inject(otSpan.context(), format: OTFormatTextMap, carrier: map)
    XCTAssertEqual(map.count, 0)
  }
}

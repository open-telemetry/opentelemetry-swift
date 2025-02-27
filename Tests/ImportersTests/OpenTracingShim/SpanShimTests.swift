/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import OpenTracingShim
import XCTest

class SpanShimTests: XCTestCase {
  let tracerProviderSdk = TracerProviderSdk()
  var tracer: Tracer!
  var telemetryInfo: TelemetryInfo!
  var span: Span!
  var tracerShim: TracerShim!

  let spanName = "Span"

  override func setUp() {
    tracer = tracerProviderSdk.get(instrumentationName: "SpanShimTest")
    telemetryInfo = TelemetryInfo(tracer: tracer, baggageManager: OpenTelemetry.instance.baggageManager, propagators: OpenTelemetry.instance.propagators)
    span = tracer.spanBuilder(spanName: spanName).startSpan()
    tracerShim = TracerShim(telemetryInfo: telemetryInfo)
  }

  override func tearDown() {
    span.end()
  }

  func testContextSimple() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let contextShim = spanShim.context() as! SpanContextShim
    XCTAssertEqual(contextShim.context, span.context)
  }

  func testBaggage() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)

    _ = spanShim.setBaggageItem("key1", value: "value1")
    _ = spanShim.setBaggageItem("key2", value: "value2")
    XCTAssertEqual(spanShim.getBaggageItem("key1"), "value1")
    XCTAssertEqual(spanShim.getBaggageItem("key2"), "value2")

    let contextShim = spanShim.context() as! SpanContextShim
    let baggageDict = TestUtils.contextBaggageToDictionary(context: contextShim)
    XCTAssertEqual(baggageDict.count, 2)
    XCTAssertEqual(baggageDict["key1"], "value1")
    XCTAssertEqual(baggageDict["key2"], "value2")
  }

  func testBaggageReplacement() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let contextShim1 = spanShim.context() as! SpanContextShim

    _ = spanShim.setBaggageItem("key1", value: "value1")
    let contextShim2 = spanShim.context() as! SpanContextShim

    XCTAssertNotEqual(contextShim1, contextShim2)
    XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: contextShim1).count, 0)
    XCTAssertNotEqual(TestUtils.contextBaggageToDictionary(context: contextShim2).count, 0)
  }

  func testBaggageDifferentShimObjs() {
    let spanShim1 = SpanShim(telemetryInfo: telemetryInfo, span: span)
    _ = spanShim1.setBaggageItem("key1", value: "value1")

    // Baggage should be synchronized among different SpanShim objects referring to the same Span.

    let spanShim2 = SpanShim(telemetryInfo: telemetryInfo, span: span)
    _ = spanShim2.setBaggageItem("key1", value: "value2")
    XCTAssertEqual(spanShim1.getBaggageItem("key1"), "value2")
    XCTAssertEqual(spanShim2.getBaggageItem("key1"), "value2")
    XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: spanShim1.context()), TestUtils.contextBaggageToDictionary(context: spanShim2.context()))
  }

  func testBaggageParent() {
    let parentSpan = tracerShim.startSpan(spanName)
    parentSpan.setBaggageItem("key1", value: "value1")
    let childSpan = tracerShim.startSpan(spanName, childOf: parentSpan.context()) as! SpanShim
    XCTAssertEqual(childSpan.getBaggageItem("key1"), "value1")
    XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: parentSpan.context()), TestUtils.contextBaggageToDictionary(context: childSpan.context()))
    childSpan.finish()
    parentSpan.finish()
  }

  func testParentNullContextShim() {
    let parentSpan = tracerShim.startSpan(spanName)
    let childSpan = tracerShim.startSpan(spanName, childOf: parentSpan.context()) as! SpanShim
    XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: childSpan.context()).count, 0)
    childSpan.finish()
    parentSpan.finish()
  }
}

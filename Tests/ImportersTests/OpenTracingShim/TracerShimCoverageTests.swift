/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import OpenTracingShim
import Opentracing
import XCTest

final class TracerShimCoverageTests: XCTestCase {
  let tracerProviderSdk = TracerProviderSdk()
  var telemetryInfo: TelemetryInfo!
  var tracerShim: TracerShim!
  private var savedTracerProvider: TracerProvider!

  override func setUp() {
    super.setUp()
    savedTracerProvider = OpenTelemetry.instance.tracerProvider
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProviderSdk)
    let tracer = tracerProviderSdk.get(instrumentationName: "TracerShimCoverageTests")
    telemetryInfo = TelemetryInfo(tracer: tracer,
                                  baggageManager: OpenTelemetry.instance.baggageManager,
                                  propagators: OpenTelemetry.instance.propagators)
    tracerShim = TracerShim(telemetryInfo: telemetryInfo)
  }

  override func tearDown() {
    OpenTelemetry.registerTracerProvider(tracerProvider: savedTracerProvider)
    super.tearDown()
  }

  func testStartSpanByName() {
    let s = tracerShim.startSpan("span-a")
    XCTAssertNotNil(s)
    s.finish()
  }

  func testStartSpanWithTags() {
    let s = tracerShim.startSpan("with-tags", tags: ["k1": "v1" as NSObject])
    let recording = (s as? SpanShim)?.span as? RecordEventsReadableSpan
    XCTAssertEqual(recording?.toSpanData().attributes["k1"], .string("v1"))
    s.finish()
  }

  func testStartSpanWithStartTime() {
    let t = Date(timeIntervalSince1970: 1_700_000_500)
    let s = tracerShim.startSpan("when", childOf: nil, tags: nil, startTime: t) as! SpanShim
    let recording = s.span as? RecordEventsReadableSpan
    XCTAssertEqual(recording?.toSpanData().startTime, t)
    s.finish()
  }

  func testStartSpanWithParentInheritsBaggage() {
    let parent = tracerShim.startSpan("p") as! SpanShim
    _ = parent.setBaggageItem("bag", value: "val")
    let child = tracerShim.startSpan("c", childOf: parent.context()) as! SpanShim
    XCTAssertEqual(child.getBaggageItem("bag"), "val")
    child.finish()
    parent.finish()
  }

  func testStartSpanWithChildOfReference() {
    let parent = tracerShim.startSpan("parent") as! SpanShim
    let ref = OTReference(type: TracerShim.OTReferenceChildOf, referencedContext: parent.context())
    let child = tracerShim.startSpan("child", references: [ref], tags: nil, startTime: nil)
    XCTAssertNotNil(child)
    child.finish()
    parent.finish()
  }

  func testStartSpanWithFollowsFromReference() {
    let parent = tracerShim.startSpan("parent") as! SpanShim
    let ref = OTReference(type: TracerShim.OTReferenceFollowsFrom, referencedContext: parent.context())
    let child = tracerShim.startSpan("child", references: [ref], tags: nil, startTime: nil)
    XCTAssertNotNil(child)
    child.finish()
    parent.finish()
  }

  func testStartSpanWithUnknownReferenceIsIgnored() {
    let parent = tracerShim.startSpan("parent") as! SpanShim
    let ref = OTReference(type: "other", referencedContext: parent.context())
    let child = tracerShim.startSpan("child", references: [ref], tags: nil, startTime: nil)
    XCTAssertNotNil(child)
    child.finish()
    parent.finish()
  }

  func testInjectAndExtractTextMap() {
    let spanShim = tracerShim.startSpan("op") as! SpanShim
    let context = spanShim.context()
    let carrier = NSMutableDictionary()
    XCTAssertTrue(tracerShim.inject(context, format: OTFormatTextMap, carrier: carrier))
    XCTAssertGreaterThan(carrier.count, 0)
    spanShim.finish()
  }

  func testInjectWithWrongCarrierReturnsFalse() {
    let spanShim = tracerShim.startSpan("op") as! SpanShim
    XCTAssertFalse(tracerShim.inject(spanShim.context(), format: OTFormatTextMap, carrier: "not-a-dict"))
    spanShim.finish()
  }

  func testInjectThrowsForInvalidArguments() {
    let spanShim = tracerShim.startSpan("op") as! SpanShim
    XCTAssertThrowsError(try tracerShim.inject(spanContext: spanShim.context(),
                                               format: OTFormatTextMap,
                                               carrier: "not-a-dict"))
    spanShim.finish()
  }

  func testInjectSucceedsWithDictionary() throws {
    let spanShim = tracerShim.startSpan("op") as! SpanShim
    let carrier = NSMutableDictionary()
    try tracerShim.inject(spanContext: spanShim.context(), format: OTFormatTextMap, carrier: carrier)
    XCTAssertGreaterThan(carrier.count, 0)
    spanShim.finish()
  }

  func testExtractWithEmptyTextMapReturnsNil() {
    // Without a registered propagator yielding a trace header, extract() yields
    // nil for an empty carrier — exercises the success-type-check branch that
    // then returns nil from propagation.
    let extracted = tracerShim.extract(withFormat: OTFormatTextMap, carrier: [String: String]())
    XCTAssertNil(extracted)
  }

  func testExtractReturnsNilForWrongCarrier() {
    XCTAssertNil(tracerShim.extract(withFormat: OTFormatTextMap, carrier: 42))
  }

  func testExtractReturnsNilForWrongFormat() {
    XCTAssertNil(tracerShim.extract(withFormat: "unknown", carrier: ["": ""]))
  }

  func testExtractWithFormatThrowsForInvalidCarrier() {
    XCTAssertThrowsError(try tracerShim.extractWithFormat(format: OTFormatTextMap, carrier: 42))
  }

  func testExtractWithFormatThrowsForUnknownFormat() {
    XCTAssertThrowsError(try tracerShim.extractWithFormat(format: "unknown", carrier: ["": ""]))
  }

  func testExtractWithFormatThrowsWhenPropagationReturnsNil() {
    // With no propagator emitting a valid header, propagation yields nil and
    // extractWithFormat throws — exercises the trailing throw branch.
    XCTAssertThrowsError(try tracerShim.extractWithFormat(format: OTFormatTextMap,
                                                          carrier: [String: String]()))
  }
}

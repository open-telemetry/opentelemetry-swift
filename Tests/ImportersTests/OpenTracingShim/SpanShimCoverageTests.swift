/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import OpenTracingShim
import Opentracing
import XCTest

final class SpanShimCoverageTests: XCTestCase {
  let tracerProviderSdk = TracerProviderSdk()
  var tracer: Tracer!
  var telemetryInfo: TelemetryInfo!
  var span: Span!

  override func setUp() {
    super.setUp()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProviderSdk)
    tracer = tracerProviderSdk.get(instrumentationName: "SpanShimCoverageTests")
    telemetryInfo = TelemetryInfo(tracer: tracer,
                                  baggageManager: OpenTelemetry.instance.baggageManager,
                                  propagators: OpenTelemetry.instance.propagators)
    span = tracer.spanBuilder(spanName: "Span").startSpan()
  }

  override func tearDown() {
    span.end()
    super.tearDown()
  }

  func testSetOperationNameRenamesSpan() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setOperationName("new-name")
    let recording = span as? RecordEventsReadableSpan
    XCTAssertEqual(recording?.name, "new-name")
  }

  func testTracerReturnsGlobalShim() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let t = spanShim.tracer()
    XCTAssertNotNil(t)
    XCTAssert(t === TraceShim.instance.otTracer)
  }

  func testSetStringTagSetsAttribute() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setTag("custom", value: "value1")
    let attrs = (span as? RecordEventsReadableSpan)?.toSpanData().attributes ?? [:]
    XCTAssertEqual(attrs["custom"], .string("value1"))
  }

  func testSetErrorTagStringTrueSetsErrorStatus() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setTag("error", value: "true")
    XCTAssertEqual((span as? RecordEventsReadableSpan)?.toSpanData().status, .error(description: "error"))
  }

  func testSetErrorTagStringFalseSetsOkStatus() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setTag("error", value: "false")
    XCTAssertEqual((span as? RecordEventsReadableSpan)?.toSpanData().status, .ok)
  }

  func testSetBoolTagSetsAttribute() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setTag("flag", boolValue: true)
    let attrs = (span as? RecordEventsReadableSpan)?.toSpanData().attributes ?? [:]
    XCTAssertEqual(attrs["flag"], .bool(true))
  }

  func testSetErrorBoolTagSetsStatus() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setTag("error", boolValue: true)
    XCTAssertEqual((span as? RecordEventsReadableSpan)?.toSpanData().status, .error(description: "error"))
    spanShim.setTag("error", boolValue: false)
    XCTAssertEqual((span as? RecordEventsReadableSpan)?.toSpanData().status, .ok)
  }

  func testSetNumberTagConvertsInt() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setTag("int-tag", numberValue: NSNumber(value: 42))
    let attrs = (span as? RecordEventsReadableSpan)?.toSpanData().attributes ?? [:]
    XCTAssertEqual(attrs["int-tag"], .int(42))
  }

  func testSetNumberTagConvertsDouble() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.setTag("double-tag", numberValue: NSNumber(value: 1.5))
    let attrs = (span as? RecordEventsReadableSpan)?.toSpanData().attributes ?? [:]
    XCTAssertEqual(attrs["double-tag"], .double(1.5))
  }

  func testSetNumberTagConvertsBool() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    // NSNumber(value: true/false) uses charType internally
    spanShim.setTag("bool-tag", numberValue: NSNumber(value: true))
    let attrs = (span as? RecordEventsReadableSpan)?.toSpanData().attributes ?? [:]
    XCTAssertEqual(attrs["bool-tag"], .bool(true))
  }

  func testLogFieldsAddsEvent() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.log(["event": "click" as NSString, "detail": "left" as NSString])
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events.first?.name, "click")
    XCTAssertEqual(events.first?.attributes["detail"], .string("left"))
  }

  func testLogFieldsWithoutEventNameUsesDefault() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.log(["detail": "no-event-key" as NSString])
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.first?.name, "log")
  }

  func testLogFieldsWithTimestamp() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let ts = Date(timeIntervalSince1970: 1_700_000_000)
    spanShim.log(["event": "t" as NSString], timestamp: ts)
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.first?.timestamp, ts)
  }

  func testLogFieldsNilTimestampDefaultsToNow() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let before = Date()
    spanShim.log(["event": "t" as NSString], timestamp: nil)
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertNotNil(events.first?.timestamp)
    XCTAssertGreaterThanOrEqual(events.first!.timestamp, before.addingTimeInterval(-1))
  }

  func testLogEventName() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.logEvent("user-action")
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.first?.name, "user-action")
  }

  func testLogEventWithPayload() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.logEvent("named", payload: "payload-value" as NSString)
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.first?.name, "named")
    XCTAssertEqual(events.first?.attributes["named"], .string("payload-value"))
  }

  func testLogEventWithNilPayload() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    spanShim.logEvent("no-payload", payload: nil)
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.first?.name, "no-payload")
    XCTAssertEqual(events.first?.attributes.count, 0)
  }

  func testLogEventFullFormWithTimestampAndPayload() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let ts = Date(timeIntervalSince1970: 1_700_000_001)
    spanShim.log("evt", timestamp: ts, payload: NSNumber(value: 9))
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.first?.name, "evt")
    XCTAssertEqual(events.first?.timestamp, ts)
    XCTAssertEqual(events.first?.attributes["evt"], .int(9))
  }

  func testLogEventFullFormNilPayload() {
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let ts = Date(timeIntervalSince1970: 1_700_000_002)
    spanShim.log("evt-no-payload", timestamp: ts, payload: nil)
    let events = (span as? RecordEventsReadableSpan)?.toSpanData().events ?? []
    XCTAssertEqual(events.first?.name, "evt-no-payload")
    XCTAssertEqual(events.first?.attributes.count, 0)
    XCTAssertEqual(events.first?.timestamp, ts)
  }

  func testFinishEndsSpan() {
    let s = tracer.spanBuilder(spanName: "finish-test").startSpan()
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: s)
    spanShim.finish()
    XCTAssertTrue((s as? RecordEventsReadableSpan)?.hasEnded ?? false)
  }

  func testFinishWithTime() {
    let s = tracer.spanBuilder(spanName: "finish-time-test").startSpan()
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: s)
    let end = Date(timeIntervalSince1970: 1_700_000_100)
    spanShim.finish(withTime: end)
    XCTAssertTrue((s as? RecordEventsReadableSpan)?.hasEnded ?? false)
    XCTAssertEqual((s as? RecordEventsReadableSpan)?.toSpanData().endTime, end)
  }

  func testFinishWithNilTimeFallsBackToNow() {
    let s = tracer.spanBuilder(spanName: "finish-nil").startSpan()
    let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: s)
    spanShim.finish(withTime: nil)
    XCTAssertTrue((s as? RecordEventsReadableSpan)?.hasEnded ?? false)
  }

  func testConvertToAttributesStringNumberFallback() {
    // NSArray is not NSString or NSNumber → falls through to empty string
    let fields: [String: NSObject] = ["arr": NSArray(array: [1, 2, 3])]
    let attrs = SpanShim.convertToAttributes(fields: fields)
    XCTAssertEqual(attrs["arr"], .string(""))
  }

  func testConvertToAttributesNumberTypes() {
    // Exercises each CFNumberType branch via NSNumber literals.
    let attrs = SpanShim.convertToAttributes(fields: [
      "int": NSNumber(value: 7),
      "double": NSNumber(value: 3.14),
      "bool": NSNumber(value: false)
    ])
    XCTAssertEqual(attrs["int"], .int(7))
    XCTAssertEqual(attrs["double"], .double(3.14))
    XCTAssertEqual(attrs["bool"], .bool(false))
  }
}

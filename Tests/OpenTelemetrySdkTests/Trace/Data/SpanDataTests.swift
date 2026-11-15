/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class SpanDataTests: XCTestCase {
  let startTime: Date = TestUtils.dateFromNanos(3000000000000 + 200)
  let endTime: Date = TestUtils.dateFromNanos(3001000000000 + 255)

  func testdefaultValues() {
    let spanData = createBasicSpan()
    XCTAssertFalse(spanData.parentSpanId?.isValid ?? false)
    XCTAssertEqual(spanData.attributes, [String: AttributeValue]())
    XCTAssertEqual(spanData.events, [SpanData.Event]())
    XCTAssertEqual(spanData.links.count, 0)
    XCTAssertEqual(InstrumentationScopeInfo(), spanData.instrumentationScope)
    XCTAssertFalse(spanData.hasRemoteParent)
  }

  private func createBasicSpan() -> SpanData {
    return SpanData(traceId: TraceId(),
                    spanId: SpanId(),
                    traceFlags: TraceFlags(),
                    traceState: TraceState(),
                    resource: Resource(),
                    instrumentationScope: InstrumentationScopeInfo(),
                    name: "spanName",
                    kind: .server,
                    startTime: startTime,
                    endTime: endTime,
                    hasRemoteParent: false)
  }

  func testSpanDataCodable() {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    var testData = createBasicSpan()
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    testData.settingHasEnded(false)
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    testData.settingAttributes(["key": AttributeValue.bool(true)])
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    testData.settingTotalAttributeCount(2)
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    testData.settingEvents([SpanData.Event(name: "my_event", timestamp: Date(timeIntervalSince1970: 12347))])
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    testData.settingTotalRecordedEvents(3)
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    let traceId = TraceId(fromBytes: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4])
    let spanId = SpanId(fromBytes: [0, 0, 0, 0, 4, 3, 2, 1])
    let spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState())
    testData.settingLinks([SpanData.Link(context: spanContext)])
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    testData.settingTotalRecordedLinks(2)
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))

    testData.settingStatus(.ok)
    XCTAssertEqual(testData, try decoder.decode(SpanData.self, from: encoder.encode(testData)))
  }
}

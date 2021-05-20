/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

fileprivate func createRandomPropagatedSpan() -> PropagatedSpan {
    return PropagatedSpan(context: SpanContext.create(traceId: TraceId.random(),
                                                      spanId: SpanId.random(),
                                                      traceFlags: TraceFlags(),
                                                      traceState: TraceState()))
}

final class PropagatedSpanTest: XCTestCase {
    func testHasInvalidContextAndDefaultSpanOptions() {
        let context = createRandomPropagatedSpan().context
        XCTAssertEqual(context.traceFlags, TraceFlags())
        XCTAssertEqual(context.traceState, TraceState())
    }

    func testHasUniqueTraceIdAndSpanId() {
        let span1 = createRandomPropagatedSpan()
        let span2 = createRandomPropagatedSpan()
        XCTAssertNotEqual(span1.context.traceId, span2.context.traceId)
        XCTAssertNotEqual(span1.context.spanId, span2.context.spanId)
    }

    func testDoNotCrash() {
        let span = createRandomPropagatedSpan()
        span.setAttribute(key: "MyStringAttributeKey", value: AttributeValue.string("MyStringAttributeValue"))
        span.setAttribute(key: "MyBooleanAttributeKey", value: AttributeValue.bool(true))
        span.setAttribute(key: "MyLongAttributeKey", value: AttributeValue.int(123))
        span.setAttribute(key: "MyEmptyStringAttributeKey", value: AttributeValue.string(""))
        span.setAttribute(key: "MyNilAttributeKey", value: nil)
        span.setAttribute(key: "MyEmptyStringArrayAttributeKey", value: AttributeValue.stringArray([]))
        span.setAttribute(key: "MyEmptyBoolArrayAttributeKey", value: AttributeValue.boolArray([]))
        span.setAttribute(key: "MyEmptyIntArrayAttributeKey", value: AttributeValue.intArray([]))
        span.setAttribute(key: "MyEmptyDoubleArrayAttributeKey", value: AttributeValue.doubleArray([]))
        span.addEvent(name: "event")
        span.addEvent(name: "event", timestamp: Date(timeIntervalSinceReferenceDate: 0))
        span.addEvent(name: "event", attributes: ["MyBooleanAttributeKey": AttributeValue.bool(true)])
        span.addEvent(name: "event", attributes: ["MyBooleanAttributeKey": AttributeValue.bool(true)], timestamp: Date(timeIntervalSinceReferenceDate: 1.5))
        span.status = .ok
        span.end()
        span.end(time: Date())
    }

    func testDefaultSpan_ToString() {
        let span = createRandomPropagatedSpan()
        XCTAssertEqual(span.description, "PropagatedSpan")
    }

    func testDefaultSpan_NilEndSpanOptions() {
        let span = PropagatedSpan()
        span.end()
    }
}

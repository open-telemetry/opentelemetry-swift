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
        span.setAttribute(key: "MyEmptyStringArrayAttributeKey", value: .array(AttributeArray.empty))
        span.setAttribute(key: "MyEmptyBoolArrayAttributeKey", value: .array(AttributeArray.empty))
        span.setAttribute(key: "MyEmptyIntArrayAttributeKey", value: .array(AttributeArray.empty))
        span.setAttribute(key: "MyEmptyDoubleArrayAttributeKey", value: .array(AttributeArray.empty))
        span.addEvent(name: "event")
        span.addEvent(name: "event", timestamp: Date(timeIntervalSinceReferenceDate: 0))
        span.addEvent(name: "event", attributes: ["MyBooleanAttributeKey": AttributeValue.bool(true)])
        span.addEvent(name: "event", attributes: ["MyBooleanAttributeKey": AttributeValue.bool(true)], timestamp: Date(timeIntervalSinceReferenceDate: 1.5))
        span.recordException(NSError(domain: "test", code: 0), timestamp: Date(timeIntervalSinceReferenceDate: 3))
        span.recordException(NSError(domain: "test", code: 0), attributes: ["MyBooleanAttributeKey": AttributeValue.bool(true)], timestamp: Date(timeIntervalSinceReferenceDate: 4.5))

#if !os(Linux)
        span.recordException(NSException(name: .genericException, reason: nil))
        span.recordException(NSException(name: .genericException, reason: nil), attributes: ["MyStringAttributeKey": AttributeValue.string("MyStringAttributeValue")])
#endif

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

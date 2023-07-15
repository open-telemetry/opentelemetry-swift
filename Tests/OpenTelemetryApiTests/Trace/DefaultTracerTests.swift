/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

@testable import OpenTelemetryApi
import XCTest
import OpenTelemetryTestUtils

private func createRandomPropagatedSpan() -> PropagatedSpan {
    return PropagatedSpan(context: SpanContext.create(traceId: TraceId.random(),
                                                      spanId: SpanId.random(),
                                                      traceFlags: TraceFlags(),
                                                      traceState: TraceState()))
}

#if canImport(os.activity)
class DefaultTracerTestsActivity: DefaultTracerTestsServiceContext {
    override class var contextManager: ContextManager { ActivityContextManager() }
}
#endif

class DefaultTracerTestsServiceContext: ContextManagerTestCase {
    override class var contextManager: ContextManager { ServiceContextManager() }

    let defaultTracer = DefaultTracer.instance
    let spanName = "MySpanName"
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]

    var spanContext: SpanContext!

    override func setUp() {
        super.setUp()
        spanContext = SpanContext.create(traceId: TraceId(fromBytes: firstBytes), spanId: SpanId(fromBytes: firstBytes, withOffset: 8), traceFlags: TraceFlags(), traceState: TraceState())
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan, "Test must start without context")

    }

    override func tearDown() {
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan, "Test must clean span context")
    }

    func testDefaultGetCurrentSpan() {
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan is PropagatedSpan?)
    }

    func testGetCurrentSpan_WithSpan() {
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan == nil)
        let span = createRandomPropagatedSpan()
        OpenTelemetry.instance.contextProvider.withActiveSpan(span) {
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan != nil)
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan is PropagatedSpan)
        }

        span.end()
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan == nil)
    }

    func testDefaultSpanBuilderWithName() {
        XCTAssert(defaultTracer.spanBuilder(spanName: spanName).startSpan() is PropagatedSpan)
    }

    func testTestInProcessContext() {
        let span = defaultTracer.spanBuilder(spanName: spanName).startSpan()
        OpenTelemetry.instance.contextProvider.withActiveSpan(span) {
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span)

            let secondSpan = defaultTracer.spanBuilder(spanName: spanName).startSpan()
            OpenTelemetry.instance.contextProvider.withActiveSpan(secondSpan, {
                XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === secondSpan)
            })
            secondSpan.end()
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span)
        }

        span.end()
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan == nil)
    }

    func testTestSpanContextPropagationExplicitParent() {
        let span = defaultTracer.spanBuilder(spanName: spanName).setParent(spanContext).startSpan()
        XCTAssert(span.context == spanContext)
    }

    func testTestSpanContextPropagation() {
        let parent = PropagatedSpan(context: spanContext)

        let span = defaultTracer.spanBuilder(spanName: spanName).setParent(parent).startSpan()
        XCTAssert(span.context == spanContext)
    }

    func testTestSpanContextPropagationCurrentSpan() {
        let parent = PropagatedSpan(context: spanContext)
        OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
            let span = defaultTracer.spanBuilder(spanName: spanName).startSpan()
            XCTAssert(span.context == spanContext)
            span.end()
        }

        parent.end()
    }
}

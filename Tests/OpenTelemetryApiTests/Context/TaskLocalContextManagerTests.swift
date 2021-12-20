/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

#if swift(>=5.5.2)
class TaskLocalContextManagerTests: XCTestCase {
    let defaultTracer = DefaultTracer.instance
    let spanName = "MySpanName"
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]

    var spanContext: SpanContext!

    override func setUp() {
        spanContext = SpanContext.create(traceId: TraceId(fromBytes: firstBytes), spanId: SpanId(fromBytes: firstBytes, withOffset: 8), traceFlags: TraceFlags(), traceState: TraceState())
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    override func tearDown() {
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func testStartAndEndSpanInAsyncTask() async {
        let span1 = defaultTracer.spanBuilder(spanName: "FirstSpan").startSpan()
        TaskLocalContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === span1)

        await createAsyncSpan(parentSpan: span1)
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
        span1.end()
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === nil)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func testStartAndEndSpanInAsyncTaskTwice() async {
        let span1 = defaultTracer.spanBuilder(spanName: "FirstSpan").startSpan()
        TaskLocalContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
        await createAsyncSpan(parentSpan: span1)
        await createAsyncSpan(parentSpan: span1)
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
        span1.end()
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === nil)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func createAsyncSpan(parentSpan: Span) async {
        let activeSpan = TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === parentSpan)
        let newSpan = defaultTracer.spanBuilder(spanName: "AsyncSpan").startSpan()
        TaskLocalContextManager.instance.setCurrentContextValue(forKey: .span, value: newSpan)
        endSpanAndValidateContext(span: newSpan, parentSpan: parentSpan)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func endSpanAndValidateContext(span: Span, parentSpan: Span) {
        var activeSpan = TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === span)
        span.end()
        activeSpan = TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === parentSpan)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func testStartAndEndSpanInAsyncTaskAnidated() async {
        let span1 = defaultTracer.spanBuilder(spanName: "FirstSpan").startSpan()
        TaskLocalContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
        await createAsyncSpanOutside(parentSpan: span1)
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
        span1.end()
        XCTAssert(TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span) === nil)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func createAsyncSpanOutside(parentSpan: Span) async {
        let activeSpan = TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === parentSpan)
        let newSpan = defaultTracer.spanBuilder(spanName: "OutsideSpan").startSpan()
        TaskLocalContextManager.instance.setCurrentContextValue(forKey: .span, value: newSpan)
        await createAsyncSpanInside(parentSpan: newSpan)
        endSpanAndValidateContext(span: newSpan, parentSpan: parentSpan)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    func createAsyncSpanInside(parentSpan: Span) async {
        let activeSpan = TaskLocalContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === parentSpan)
        let newSpan = defaultTracer.spanBuilder(spanName: "InsideSpan").startSpan()
        TaskLocalContextManager.instance.setCurrentContextValue(forKey: .span, value: newSpan)
        await createAsyncSpan(parentSpan: newSpan)
        endSpanAndValidateContext(span: newSpan, parentSpan: parentSpan)
    }
}

#endif

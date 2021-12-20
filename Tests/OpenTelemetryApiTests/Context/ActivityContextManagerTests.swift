/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class ActivityContextManagerTests: XCTestCase {
    let defaultTracer = DefaultTracer.instance
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]

    var spanContext: SpanContext!

    override func setUp() {
        spanContext = SpanContext.create(traceId: TraceId(fromBytes: firstBytes), spanId: SpanId(fromBytes: firstBytes, withOffset: 8), traceFlags: TraceFlags(), traceState: TraceState())
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    override func tearDown() {
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    func testStartAndEndSpanInAsyncQueue() {
        let span1 = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncQueue1").startSpan()
        ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
        XCTAssert(ActivityContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
        DispatchQueue.global().async {
            let span2 = self.createSpan(parentSpan: span1, name: "testStartAndEndSpanInAsyncQueue2")
            self.endSpanAndValidateContext(span: span2, parentSpan: span1)
        }
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span1)
        span1.end()
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    func testStartAndEndSpanInAsyncQueueTwice() {
        let span1 = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncQueueTwice1").startSpan()
        ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
        XCTAssert(ActivityContextManager.instance.getCurrentContextValue(forKey: .span) === span1)

        DispatchQueue.global().async {
            let span2 = self.createSpan(parentSpan: span1, name: "testStartAndEndSpanInAsyncQueueTwice2")
            self.endSpanAndValidateContext(span: span2, parentSpan: span1)
        }
        DispatchQueue.global().async {
            let span3 = self.createSpan(parentSpan: span1, name: "testStartAndEndSpanInAsyncQueueTwice3")
            self.endSpanAndValidateContext(span: span3, parentSpan: span1)
        }
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span1)
        span1.end()
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    func createSpan(parentSpan: Span, name: String) -> Span {
        var activeSpan = ActivityContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === parentSpan)
        let newSpan = defaultTracer.spanBuilder(spanName: name).startSpan()
        ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: newSpan)
        activeSpan = ActivityContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === newSpan)
        return newSpan
    }

    func endSpanAndValidateContext(span: Span, parentSpan: Span?) {
        var activeSpan = ActivityContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === span)
        span.end()
        activeSpan = ActivityContextManager.instance.getCurrentContextValue(forKey: .span)
        XCTAssert(activeSpan === parentSpan)
    }

    #if swift(>=5.5.2)
        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        func testStartAndEndSpanInAsyncTask() async {
            let span1 = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTask1").startSpan()
            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
            XCTAssert(ActivityContextManager.instance.getCurrentContextValue(forKey: .span) === span1)

            await createAsyncSpan(parentSpan: span1)
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span1)
            span1.end()
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
        }

//        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
//        func testStartAndEndSpanInAsyncTaskTwice() async {
//            let span1 = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTaskTwice1").startSpan()
//            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
//            XCTAssert(ActivityContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
//            async let one: () = createAsyncSpan(parentSpan: span1)
//            async let two: () = createAsyncSpan(parentSpan: span1)
//            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span1)
//            span1.end()
//            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
//            await one
//            await two
//        }

        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        func createAsyncSpan(parentSpan: Span?) async {
            let activeSpan = ActivityContextManager.instance.getCurrentContextValue(forKey: .span)
            XCTAssert(activeSpan === parentSpan)
            let newSpan = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTaskTwice2").startSpan()
            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: newSpan)
            endSpanAndValidateContext(span: newSpan, parentSpan: parentSpan)
        }

        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        func testStartAndEndSpanInAsyncTaskAnidated() async {
            let span1 = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTaskAnidated1").startSpan()
            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
            XCTAssert(ActivityContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
            await createAsyncSpanOutside(parentSpan: span1)
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span1)
            span1.end()
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
        }

        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        func createAsyncSpanOutside(parentSpan: Span) async {
            let activeSpan = ActivityContextManager.instance.getCurrentContextValue(forKey: .span)
            XCTAssert(activeSpan === parentSpan)
            let newSpan = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTaskAnidated2").startSpan()
            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: newSpan)
            await createAsyncSpanInside(parentSpan: newSpan)
            endSpanAndValidateContext(span: newSpan, parentSpan: parentSpan)
        }

        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        func createAsyncSpanInside(parentSpan: Span) async {
            let activeSpan = ActivityContextManager.instance.getCurrentContextValue(forKey: .span)
            XCTAssert(activeSpan === parentSpan)
            let newSpan = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTaskAnidated3").startSpan()
            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: newSpan)
            await createAsyncSpan(parentSpan: newSpan)
            endSpanAndValidateContext(span: newSpan, parentSpan: parentSpan)
        }

        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        // First created task correctly does not inherit activity when created detached
        func testStartAndEndSpanInAsyncTaskDetachedWithParent() {
            let span1 = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTask1").startSpan()
            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
            let expec = expectation(description: "testStartAndEndSpanInAsyncTaskWithParent")
            Task.detached {
                XCTAssert(ActivityContextManager.instance.getCurrentContextValue(forKey: .span) === nil)
                await self.createAsyncSpan(parentSpan: nil)
                XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
                expec.fulfill()
            }
            span1.end()
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
            waitForExpectations(timeout: 30)
        }

        @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
        // First created task correctly inherits activity when created, so assigns the proper parent
        func testStartAndEndSpanInAsyncTaskWithParent() {
            let span1 = defaultTracer.spanBuilder(spanName: "testStartAndEndSpanInAsyncTask1").startSpan()
            ActivityContextManager.instance.setCurrentContextValue(forKey: .span, value: span1)
            let expec = expectation(description: "testStartAndEndSpanInAsyncTaskWithParent")
            Task {
                XCTAssert(ActivityContextManager.instance.getCurrentContextValue(forKey: .span) === span1)
                await self.createAsyncSpan(parentSpan: span1)
                XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === span1)
                expec.fulfill()
            }
            span1.end()
            XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
            waitForExpectations(timeout: 30)
        }

    #endif
}

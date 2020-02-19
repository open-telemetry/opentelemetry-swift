// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

@testable import OpenTelemetryApi
import XCTest

final class DefaultTracerTests: XCTestCase {
    let defaultTracer = DefaultTracer.instance
    let spanName = "MySpanName"
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]

    var spanContext: SpanContext!

    override func setUp() {
        spanContext = SpanContext.create(traceId: TraceId(fromBytes: firstBytes), spanId: SpanId(fromBytes: firstBytes, withOffset: 8), traceFlags: TraceFlags(), traceState: TraceState())
    }

    func testDefaultGetCurrentSpan() {
        XCTAssert(defaultTracer.currentSpan is DefaultSpan?)
    }

    func testGetCurrentSpan_WithSpan() {
        XCTAssert(defaultTracer.currentSpan == nil)
        var ws = defaultTracer.withSpan(DefaultSpan.random())
        XCTAssert(defaultTracer.currentSpan != nil)
        XCTAssert(defaultTracer.currentSpan is DefaultSpan)
        ws.close()
        XCTAssert(defaultTracer.currentSpan == nil)
    }

    func testDefaultSpanBuilderWithName() {
        XCTAssert(defaultTracer.spanBuilder(spanName: spanName).startSpan() is DefaultSpan)
    }

    func testDefaultHttpTextFormat() {
        XCTAssert(defaultTracer.textFormat is HttpTraceContextFormat)
    }

    func testDefaultBinarytFormat() {
        XCTAssert(defaultTracer.binaryFormat is BinaryTraceContextFormat)
    }

    func testTestInProcessContext() {
        let span = defaultTracer.spanBuilder(spanName: spanName).startSpan()
        var scope = defaultTracer.withSpan(span)
        XCTAssert(defaultTracer.currentSpan === span)

        let secondSpan = defaultTracer.spanBuilder(spanName: spanName).startSpan()
        var secondScope = defaultTracer.withSpan(secondSpan)

        XCTAssert(defaultTracer.currentSpan === secondSpan)

        secondScope.close()
        XCTAssert(defaultTracer.currentSpan === span)

        scope.close()
        XCTAssert(defaultTracer.currentSpan == nil)
    }

    func testTestSpanContextPropagationExplicitParent() {
        let span = defaultTracer.spanBuilder(spanName: spanName).setParent(spanContext).startSpan()
        XCTAssert(span.context === spanContext)
    }

    func testTestSpanContextPropagation() {
        let parent = DefaultSpan(context: spanContext)

        let span = defaultTracer.spanBuilder(spanName: spanName).setParent(parent).startSpan()
        XCTAssert(span.context === spanContext)
    }

    func testTestSpanContextPropagationCurrentSpan() {
        let parent = DefaultSpan(context: spanContext)
        var scope = defaultTracer.withSpan(parent)
        let span = defaultTracer.spanBuilder(spanName: spanName).startSpan()
        XCTAssert(span.context === spanContext)
        scope.close()
    }
}

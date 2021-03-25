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

@testable import OpenTelemetryApi
import XCTest

final class DefaultSpanTest: XCTestCase {
    func testHasInvalidContextAndDefaultSpanOptions() {
        let context = PropagatedSpan.random().context
        XCTAssertEqual(context.traceFlags, TraceFlags())
        XCTAssertEqual(context.traceState, TraceState())
    }

    func testHasUniqueTraceIdAndSpanId() {
        let span1 = PropagatedSpan.random()
        let span2 = PropagatedSpan.random()
        XCTAssertNotEqual(span1.context.traceId, span2.context.traceId)
        XCTAssertNotEqual(span1.context.spanId, span2.context.spanId)
    }

    func testDoNotCrash() {
        let span = PropagatedSpan.random()
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
        let span = PropagatedSpan.random()
        XCTAssertEqual(span.description, "PropagatedSpan")
    }

    func testDefaultSpan_NilEndSpanOptions() {
        let span = PropagatedSpan()
        span.end()
    }
}

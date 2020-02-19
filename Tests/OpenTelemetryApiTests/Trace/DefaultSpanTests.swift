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

final class TestEvent: Event {
    var name: String {
        return "name"
    }

    var attributes: [String: AttributeValue] {
        return [String: AttributeValue]()
    }
}

final class DefaultSpanTest: XCTestCase {
    func testHasInvalidContextAndDefaultSpanOptions() {
        let context = DefaultSpan.random().context
        XCTAssertEqual(context.traceFlags, TraceFlags())
        XCTAssertEqual(context.traceState, TraceState())
    }

    func testHasUniqueTraceIdAndSpanId() {
        let span1 = DefaultSpan.random()
        let span2 = DefaultSpan.random()
        XCTAssertNotEqual(span1.context.traceId, span2.context.traceId)
        XCTAssertNotEqual(span1.context.spanId, span2.context.spanId)
    }

    func testDoNotCrash() {
        let span = DefaultSpan.random()
        span.setAttribute(key: "MyStringAttributeKey", value: AttributeValue.string("MyStringAttributeValue"))
        span.setAttribute(key: "MyBooleanAttributeKey", value: AttributeValue.bool(true))
        span.setAttribute(key: "MyLongAttributeKey", value: AttributeValue.int(123))
        span.setAttribute(key: "MyBooleanAttributeKey", value: AttributeValue.string(nil))
        span.setAttribute(key: "MyLongAttributeKey", value: AttributeValue.string(""))
        span.addEvent(name: "event")
        span.addEvent(name: "event", timestamp: 0)
        span.addEvent(name: "event", attributes: ["MyBooleanAttributeKey": AttributeValue.bool(true)])
        span.addEvent(name: "event", attributes: ["MyBooleanAttributeKey": AttributeValue.bool(true)], timestamp: 0)
        span.addEvent(event: TestEvent())
        span.addEvent(event: TestEvent(), timestamp: 0)
        span.status = .ok
        span.end()
        span.end(endOptions: EndSpanOptions())
    }

    func testDefaultSpan_ToString() {
        let span = DefaultSpan.random()
        XCTAssertEqual(span.description, "DefaultSpan")
    }

    func testDefaultSpan_NilEndSpanOptions() {
        let span = DefaultSpan()
        span.end()
    }
}

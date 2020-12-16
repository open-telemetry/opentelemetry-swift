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

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class SpanDataEventTests: XCTestCase {
    static let eventName = "event"
    static let eventName2 = "event2"
    static let attributes = ["attribute": AttributeValue.string("value")]
    static let attributes2 = ["attribute2": AttributeValue.string("value2")]

    func testRawTimedEventWithName() {
        let event = SpanData.Event(name: SpanDataEventTests.eventName, epochNanos: 1000)
        XCTAssertEqual(event.epochNanos, 1000)
        XCTAssertEqual(event.name, SpanDataEventTests.eventName)
        XCTAssertEqual(event.attributes.count, 0)
    }

    func testRawTimedEventWithNameAndAttributes() {
        let event = SpanData.Event(name: SpanDataEventTests.eventName, epochNanos: 2000, attributes: SpanDataEventTests.attributes)
        XCTAssertEqual(event.epochNanos, 2000)
        XCTAssertEqual(event.name, SpanDataEventTests.eventName)
        XCTAssertEqual(event.attributes, SpanDataEventTests.attributes)
    }

    func testRawTimedEventWithDate() {
        let dateForEvent = Date()
        let event = SpanData.Event(name: SpanDataEventTests.eventName, timestamp: dateForEvent)
        XCTAssertEqual(event.epochNanos, UInt64(dateForEvent.timeIntervalSince1970.toNanoseconds))
        XCTAssertEqual(event.name, SpanDataEventTests.eventName)
        XCTAssertEqual(event.attributes.count, 0)
    }
}

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
@testable import OpenTelemetrySdk
import XCTest

class TimedEventTests: XCTestCase {
    struct TestEvent: Event {
        var name = TimedEventTests.eventName2
        var attributes = TimedEventTests.attributes2
    }

    static let eventName = "event"
    static let eventName2 = "event2"
    static let attributes = ["attribute": AttributeValue.string("value")]
    static let attributes2 = ["attribute2": AttributeValue.string("value2")]
    let testEvent = TestEvent()

    func testRawTimedEventWithName() {
        let event = TimedEvent(nanotime: 1000, name: TimedEventTests.eventName)
        XCTAssertEqual(event.epochNanos, 1000)
        XCTAssertEqual(event.name, TimedEventTests.eventName)
        XCTAssertEqual(event.attributes.count, 0)
    }

    func testRawTimedEventWithNameAndAttributes() {
        let event = TimedEvent(nanotime: 2000, name: TimedEventTests.eventName, attributes: TimedEventTests.attributes)
        XCTAssertEqual(event.epochNanos, 2000)
        XCTAssertEqual(event.name, TimedEventTests.eventName)
        XCTAssertEqual(event.attributes, TimedEventTests.attributes)
    }

    func testTimedEventWithEvent() {
        let event = TimedEvent(nanotime: 3000, event: testEvent)
        XCTAssertEqual(event.epochNanos, 3000)
        XCTAssertEqual(event.name, TimedEventTests.eventName2)
        XCTAssertEqual(event.attributes, TimedEventTests.attributes2)
    }
}

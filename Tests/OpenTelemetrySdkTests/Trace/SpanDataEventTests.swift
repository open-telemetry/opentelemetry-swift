/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class SpanDataEventTests: XCTestCase {
  static let eventName = "event"
  static let eventName2 = "event2"
  static let attributes = ["attribute": AttributeValue.string("value")]
  static let attributes2 = ["attribute2": AttributeValue.string("value2")]

  func testRawTimedEventWithName() {
    let event = SpanData.Event(name: SpanDataEventTests.eventName, timestamp: Date(timeIntervalSince1970: 1000))
    XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 1000))
    XCTAssertEqual(event.name, SpanDataEventTests.eventName)
    XCTAssertEqual(event.attributes.count, 0)
  }

  func testRawTimedEventWithNameAndAttributes() {
    let event = SpanData.Event(name: SpanDataEventTests.eventName, timestamp: Date(timeIntervalSince1970: 2000), attributes: SpanDataEventTests.attributes)
    XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 2000))
    XCTAssertEqual(event.name, SpanDataEventTests.eventName)
    XCTAssertEqual(event.attributes, SpanDataEventTests.attributes)
  }

  func testRawTimedEventWithDate() {
    let dateForEvent = Date()
    let event = SpanData.Event(name: SpanDataEventTests.eventName, timestamp: dateForEvent)
    XCTAssertEqual(event.timestamp, dateForEvent)
    XCTAssertEqual(event.name, SpanDataEventTests.eventName)
    XCTAssertEqual(event.attributes.count, 0)
  }
}

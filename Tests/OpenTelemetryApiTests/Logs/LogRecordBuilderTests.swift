//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import OpenTelemetryApi

final class LogRecordBuilderTests: XCTestCase {
  
  func testSetTimestampDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    let result = builder.setTimestamp(Date())
    XCTAssertTrue(result === builder)
  }
  
  func testSetObservedTimestampDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    let result = builder.setObservedTimestamp(Date())
    XCTAssertTrue(result === builder)
  }
  
  func testSetSpanContextDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    let spanContext = SpanContext.create(traceId: TraceId(), spanId: SpanId(), traceFlags: TraceFlags(), traceState: TraceState())
    let result = builder.setSpanContext(spanContext)
    XCTAssertTrue(result === builder)
  }
  
  func testSetSeverityDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    let result = builder.setSeverity(.info)
    XCTAssertTrue(result === builder)
  }
  
  func testSetBodyDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    let result = builder.setBody(AttributeValue.string("test"))
    XCTAssertTrue(result === builder)
  }
  
  func testSetAttributesDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    let result = builder.setAttributes(["key": AttributeValue.string("value")])
    XCTAssertTrue(result === builder)
  }
  
  func testSetEventNameDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    let result = builder.setEventName("test.event")
    XCTAssertTrue(result === builder)
  }
  
  func testEmitDefaultImplementation() {
    let builder = MockLogRecordBuilder()
    builder.emit() // Should not crash
  }
}

private class MockLogRecordBuilder: LogRecordBuilder {}
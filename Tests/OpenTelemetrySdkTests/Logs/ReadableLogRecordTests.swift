//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class ReadableLogRecordTests: XCTestCase {
  let processor = LogRecordProcessorMock()

  func testLogRecord() {
    let observedTimestamp = Date()
    let provider = LoggerProviderBuilder().with(logLimits: LogLimits(maxAttributeCount: 1, maxAttributeLength: 1)).with(processors: [processor]).build()
    let logger = provider.get(instrumentationScopeName: "temp")
    logger.logRecordBuilder()
      .setBody(AttributeValue.string("hello, world"))
      .setSeverity(.debug)
      .setObservedTimestamp(observedTimestamp)
      .setAttributes(["firstAttribute": AttributeValue.string("only the 'o' will be captured"), "secondAttribute": AttributeValue.string("this attribute will be dropped")])
      .emit()

    let logRecord = processor.onEmitCalledLogRecord
    XCTAssertEqual(logRecord?.observedTimestamp, observedTimestamp)
    XCTAssertEqual(logRecord?.body, AttributeValue.string("hello, world"))
    XCTAssertEqual(logRecord?.attributes.count, 1)
    let key = logRecord?.attributes.keys.first
    XCTAssertEqual(logRecord?.attributes[key!]?.description.count, 1)
  }

  func testEventName() {
    let logRecordWithEvent = ReadableLogRecord(
      resource: Resource(),
      instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
      timestamp: Date(),
      attributes: [:],
      eventName: "user.login"
    )
    XCTAssertEqual(logRecordWithEvent.eventName, "user.login")
  }

  func testWithoutEventName()  {
    let logRecordWithoutEvent = ReadableLogRecord(
      resource: Resource(),
      instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
      timestamp: Date(),
      attributes: [:]
    )
    XCTAssertNil(logRecordWithoutEvent.eventName)
  }

  func testSetAttribute() {
    var logRecord = ReadableLogRecord(
      resource: Resource(),
      instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
      timestamp: Date(),
      attributes: [:]
    )

    // Test string attribute
    logRecord.setAttribute(key: "stringKey", value: "stringValue")
    XCTAssertEqual(logRecord.attributes["stringKey"], AttributeValue.string("stringValue"))

    // Test int attribute
    logRecord.setAttribute(key: "intKey", value: 42)
    XCTAssertEqual(logRecord.attributes["intKey"], AttributeValue.int(42))

    // Test double attribute
    logRecord.setAttribute(key: "doubleKey", value: 3.14)
    XCTAssertEqual(logRecord.attributes["doubleKey"], AttributeValue.double(3.14))

    // Test bool attribute
    logRecord.setAttribute(key: "boolKey", value: true)
    XCTAssertEqual(logRecord.attributes["boolKey"], AttributeValue.bool(true))

    // Test AttributeValue attribute
    logRecord.setAttribute(key: "attributeValueKey", value: AttributeValue.string("test"))
    XCTAssertEqual(logRecord.attributes["attributeValueKey"], AttributeValue.string("test"))

    // Test nil value removes attribute
    logRecord.setAttribute(key: "stringKey", value: nil)
    XCTAssertNil(logRecord.attributes["stringKey"])

    // Test session.id attribute
    logRecord.setAttribute(key: "session.id", value: "E6BD5A6F-076A-438C-9E6E-23DCF417F2F5")
    XCTAssertEqual(logRecord.attributes["session.id"], AttributeValue.string("E6BD5A6F-076A-438C-9E6E-23DCF417F2F5"))
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
import OpenTelemetryApi

final class SpanExceptionRecorderTests: XCTestCase {
  func testOriginalSwiftErrorTypeWithAllArgumentCombinations() throws {
    enum LocalError: CustomNSError {
      case failure

      static var errorDomain: String { "Custom Error Domain" }
      var errorCode: Int { 5 }
    }

    let error: Error = LocalError.failure
    let attributeKey = "test.attribute"
    let attributes: [String: AttributeValue] = [attributeKey: .string("value")]
    let timestamp = Date(timeIntervalSince1970: 123)

    for selectedAttributes in [nil, attributes] {
      for selectedTimestamp in [nil, timestamp] {
        let recorder = Recorder()
        recorder.recordException(error, attributes: selectedAttributes, timestamp: selectedTimestamp)

        let exception = try XCTUnwrap(recorder.exception)
        XCTAssertEqual(exception.type, "OpenTelemetryApiTests.SpanExceptionRecorderTests.LocalError")
        XCTAssertEqual(exception.message, error.localizedDescription)
        XCTAssertNil(exception.stackTrace)
        XCTAssertEqual(recorder.attributes, selectedAttributes)
        XCTAssertEqual(recorder.timestamp, selectedTimestamp)
      }
    }
  }

  func testNSErrorDomainIsNotNormalized() throws {
    let nsError = NSError(domain: "Custom.(unknown context at $ABC123).Domain", code: -123)
    let error: Error = nsError
    let recorder = Recorder()
    recorder.recordException(error)

    let exception = try XCTUnwrap(recorder.exception)
    XCTAssertEqual(exception.type, "Custom.(unknown context at $ABC123).Domain (-123)")
    XCTAssertEqual(nsError.type, "Custom.(unknown context at $ABC123).Domain (-123)")
    XCTAssertEqual(exception.message, nsError.localizedDescription)
    XCTAssertNil(exception.stackTrace)
  }

  private final class Recorder: SpanExceptionRecorder {
    var exception: SpanException?
    var attributes: [String: AttributeValue]?
    var timestamp: Date?

    func recordException(_ exception: SpanException) {
      capture(exception)
    }

    func recordException(_ exception: SpanException, timestamp: Date) {
      capture(exception, timestamp: timestamp)
    }

    func recordException(_ exception: SpanException, attributes: [String: AttributeValue]) {
      capture(exception, attributes: attributes)
    }

    func recordException(_ exception: SpanException, attributes: [String: AttributeValue], timestamp: Date) {
      capture(exception, attributes: attributes, timestamp: timestamp)
    }

    private func capture(_ exception: SpanException, attributes: [String: AttributeValue]? = nil, timestamp: Date? = nil) {
      self.exception = exception
      self.attributes = attributes
      self.timestamp = timestamp
    }
  }
}

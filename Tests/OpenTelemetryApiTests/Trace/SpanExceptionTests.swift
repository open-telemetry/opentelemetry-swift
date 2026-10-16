/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreFoundation
import Foundation
import XCTest
@testable import OpenTelemetryApi

final class SpanExceptionTests: XCTestCase {
  // Keep the fixtures function-local to exercise runtime-context removal.
  func testErrorAsSpanException() {
    enum TestError: Error {
      case test
    }

    let error = TestError.test

    let exception = ErrorException(error: error)

    XCTAssertEqual(exception.type, "OpenTelemetryApiTests.SpanExceptionTests.TestError")
    XCTAssertEqual(exception.message, error.localizedDescription)
    XCTAssertNil(exception.stackTrace)
  }

  func testErrorAsSpanExceptionWithProperBridgeToCustomNSError() {
    enum TestCustomNSErrorEnum: Error, CustomNSError {
      case test

      var errorCode: Int { 5 }
    }

    let error = TestCustomNSErrorEnum.test

    let exception = ErrorException(error: error)

    XCTAssertEqual(exception.type, "OpenTelemetryApiTests.SpanExceptionTests.TestCustomNSErrorEnum")
    XCTAssertEqual(exception.message, error.localizedDescription)
    XCTAssertNil(exception.stackTrace)
  }

  func testCustomNSErrorAsSpanException() throws {
    struct TestCustomNSError: Error, CustomNSError {
      let additionalComments: String

      var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: "This is a custom NSError: \(additionalComments)"]
      }
    }

    let error = TestCustomNSError(additionalComments: "SpanExceptionTests")

    let exception = ErrorException(error: error)

    XCTAssertEqual(exception.type, "OpenTelemetryApiTests.SpanExceptionTests.TestCustomNSError")
    XCTAssertEqual(exception.message, error.localizedDescription)
    XCTAssertNil(exception.stackTrace)

    // CustomNSError supplies the localized description through errorUserInfo.
    let localizedDescription = try XCTUnwrap(error.errorUserInfo[NSLocalizedDescriptionKey] as? String)
    XCTAssertEqual(exception.message, localizedDescription)
  }

  func testPrivateErrorType() {
    let exception = ErrorException(error: PrivateError.test)

    XCTAssertEqual(exception.type, "OpenTelemetryApiTests.SpanExceptionTests.PrivateError")
  }

  func testFunctionLocalErrorType() {
    enum LocalError: Error {
      case test
    }

    let exception = ErrorException(error: LocalError.test)

    XCTAssertEqual(exception.type, "OpenTelemetryApiTests.SpanExceptionTests.LocalError")
  }

  func testNSError() {
    let nsError = NSError(domain: "Test Domain", code: 1)
    let exception = nsError as SpanException

    XCTAssertEqual(exception.type, "Test Domain (1)")
    XCTAssertEqual(ErrorException(error: nsError).type, "Test Domain (1)")
    XCTAssertEqual(exception.message, nsError.localizedDescription)
    XCTAssertNil(exception.stackTrace)
  }

  func testNSErrorSubclassPreservesDomainAndCode() {
    final class TestError: NSError, @unchecked Sendable {}

    let nsError = TestError(domain: "Subclass Domain", code: -123)
    let exception = nsError as SpanException

    XCTAssertEqual(exception.type, "Subclass Domain (-123)")
    XCTAssertEqual(ErrorException(error: nsError).type, "Subclass Domain (-123)")
    XCTAssertEqual(exception.message, nsError.localizedDescription)
    XCTAssertNil(exception.stackTrace)
  }

  #if !os(Linux)
    func testCFErrorPreservesDomainAndCode() throws {
      let cfError = try XCTUnwrap(CFErrorCreate(kCFAllocatorDefault, "CFError Domain" as CFString, -42, nil))
      let nsError = cfError as Error as NSError
      let exception = nsError as SpanException

      XCTAssertEqual(exception.type, "CFError Domain (-42)")
      XCTAssertEqual(ErrorException(error: nsError).type, "CFError Domain (-42)")
      XCTAssertEqual(exception.message, nsError.localizedDescription)
      XCTAssertNil(exception.stackTrace)
    }

    func testNSException() {
      final class TestException: NSException {
        override var callStackSymbols: [String] {
          [
            "test-stack-entry-1",
            "test-stack-entry-2",
            "test-stack-entry-3"
          ]
        }
      }

      let exceptionReason = "This is a test exception"
      let nsException = TestException(name: .genericException, reason: exceptionReason)
      let exception = nsException as SpanException

      XCTAssertEqual(exception.type, nsException.name.rawValue)
      XCTAssertEqual(exception.message, nsException.reason)
      XCTAssertEqual(exception.stackTrace, nsException.callStackSymbols)
    }
  #endif

  private enum PrivateError: Error {
    case test
  }
}

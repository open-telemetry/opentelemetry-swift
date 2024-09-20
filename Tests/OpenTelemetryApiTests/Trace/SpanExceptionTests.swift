/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
import OpenTelemetryApi

final class SpanExceptionTests: XCTestCase {
    func testErrorAsSpanException() {
        enum TestError: Error {
            case test(code: Int)
        }

        let error = TestError.test(code: 5)

        // `Error` can be converted to `NSError`, which automatically makes the cast to
        // `SpanException` possible since `NSError` conforms to `SpanException`.
        let exception = error as SpanException

#if !os(Linux)
        XCTAssertEqual(exception.type, String(reflecting: error))
#else
        XCTAssertEqual(exception.type, String(reflecting: error as NSError))
#endif
        XCTAssertEqual(exception.message, error.localizedDescription)
        XCTAssertNil(exception.stackTrace)
    }

    func testCustomNSErrorAsSpanException() throws {
        struct TestCustomNSError: Error, CustomNSError {
            let additionalComments: String

            var errorUserInfo: [String : Any] {
                [NSLocalizedDescriptionKey: "This is a custom NSError: \(additionalComments)"]
            }
        }

        let error = TestCustomNSError(additionalComments: "SpanExceptionTests")
        
        // `Error` can be converted to `NSError`, which automatically makes the cast to
        // `SpanException` possible since `NSError` conforms to `SpanException`.
        let exception = error as SpanException

#if !os(Linux)
        XCTAssertEqual(exception.type, String(reflecting: error))
#else
        XCTAssertEqual(exception.type, String(reflecting: error as NSError))
#endif
        XCTAssertEqual(exception.message, error.localizedDescription)
        XCTAssertNil(exception.stackTrace)

        // `TestCustomNSError` conforms to `CustomNSError`, so the conversion to `NSError` when casting to
        // `SpanException` should utilize that protocol and result in a custom `localizedDescription`.
        let localizedDescription = try XCTUnwrap(error.errorUserInfo[NSLocalizedDescriptionKey] as? String)
        XCTAssertEqual(exception.message, localizedDescription)
    }

    func testNSError() {
        let nsError = NSError(domain: "Test Domain", code: 1)
        let exception = nsError as SpanException

        XCTAssertEqual(exception.type, String(reflecting: nsError))
        XCTAssertEqual(exception.message, nsError.localizedDescription)
        XCTAssertNil(exception.stackTrace)
    }
    
#if !os(Linux)
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
}

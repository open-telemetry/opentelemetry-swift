//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
@testable import OpenTelemetryApi
import XCTest


class SeverityTests : XCTestCase {
    func testSeverity() {
        XCTAssertGreaterThan(Severity.trace2, Severity.trace)
        XCTAssertGreaterThan(Severity.trace3, Severity.trace)
        XCTAssertGreaterThan(Severity.trace4, Severity.trace)
        XCTAssertGreaterThan(Severity.fatal, Severity.info)
        
        XCTAssertEqual(Severity.trace.description, "TRACE")
        XCTAssertEqual(Severity.trace2.description, "TRACE2")
        XCTAssertEqual(Severity.trace3.description, "TRACE3")
        XCTAssertEqual(Severity.trace4.description, "TRACE4")
        XCTAssertEqual(Severity.debug.description, "DEBUG")
        XCTAssertEqual(Severity.debug2.description, "DEBUG2")
        XCTAssertEqual(Severity.debug3.description, "DEBUG3")
        XCTAssertEqual(Severity.debug4.description, "DEBUG4")
        XCTAssertEqual(Severity.info.description, "INFO")
        XCTAssertEqual(Severity.info2.description, "INFO2")
        XCTAssertEqual(Severity.info3.description, "INFO3")
        XCTAssertEqual(Severity.info4.description, "INFO4")
        XCTAssertEqual(Severity.warn.description, "WARN")
        XCTAssertEqual(Severity.warn2.description, "WARN2")
        XCTAssertEqual(Severity.warn3.description, "WARN3")
        XCTAssertEqual(Severity.warn4.description, "WARN4")
        XCTAssertEqual(Severity.error.description, "ERROR")
        XCTAssertEqual(Severity.error2.description, "ERROR2")
        XCTAssertEqual(Severity.error3.description, "ERROR3")
        XCTAssertEqual(Severity.error4.description, "ERROR4")
        XCTAssertEqual(Severity.fatal.description, "FATAL")
        XCTAssertEqual(Severity.fatal2.description, "FATAL2")
        XCTAssertEqual(Severity.fatal3.description, "FATAL3")
        XCTAssertEqual(Severity.fatal4.description, "FATAL4")

    }
}

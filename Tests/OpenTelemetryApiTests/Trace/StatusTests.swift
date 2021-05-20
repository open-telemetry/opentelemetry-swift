/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import XCTest

final class StatusTests: XCTestCase {
    func testStatusIsOk() {
        let statusOK = Status.ok
        XCTAssertTrue(statusOK.isOk)
        let statusUnset = Status.unset
        XCTAssertFalse(statusUnset.isOk)
        let statusError = Status.error(description: "Error")
        XCTAssertFalse(statusError.isOk)
    }

    func testStatusIsError() {
        let statusOK = Status.ok
        XCTAssertFalse(statusOK.isError)
        let statusUnset = Status.unset
        XCTAssertFalse(statusUnset.isError)
        let statusError = Status.error(description: "Error")
        XCTAssertTrue(statusError.isError)
    }
}

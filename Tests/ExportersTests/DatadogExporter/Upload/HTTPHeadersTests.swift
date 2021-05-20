/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class HTTPHeadersTests: XCTestCase {
    func testContentTypeHeader() {
        let applicationJSON = HTTPHeaders.HTTPHeader.contentTypeHeader(contentType: .applicationJSON)
        XCTAssertEqual(applicationJSON.field, "Content-Type")
        XCTAssertEqual(applicationJSON.value, "application/json")

        let plainText = HTTPHeaders.HTTPHeader.contentTypeHeader(contentType: .textPlainUTF8)
        XCTAssertEqual(plainText.field, "Content-Type")
        XCTAssertEqual(plainText.value, "text/plain;charset=UTF-8")
    }

    func testUserAgentHeader() {
        let userAgent = HTTPHeaders.HTTPHeader.userAgentHeader(
            appName: "FoobarApp",
            appVersion: "1.2.3",
            device: .mockWith(model: "iPhone", osName: "iOS", osVersion: "13.3.1")
        )
        XCTAssertEqual(userAgent.field, "User-Agent")
        XCTAssertEqual(userAgent.value, "FoobarApp/1.2.3 CFNetwork (iPhone; iOS/13.3.1)")
    }

    func testComposingHeaders() {
        let headers = HTTPHeaders(
            headers: [
                .contentTypeHeader(contentType: .applicationJSON),
                .userAgentHeader(
                    appName: "FoobarApp",
                    appVersion: "1.2.3",
                    device: .mockWith(model: "iPhone", osName: "iOS", osVersion: "13.3.1")
                )
            ]
        )

        XCTAssertEqual(
            headers.all,
            [
                "Content-Type": "application/json",
                "User-Agent": "FoobarApp/1.2.3 CFNetwork (iPhone; iOS/13.3.1)"
            ]
        )
    }
}

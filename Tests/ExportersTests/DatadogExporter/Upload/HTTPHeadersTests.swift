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

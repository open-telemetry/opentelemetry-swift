/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import SharedTestUtils

final class HTTPTypesTests: XCTestCase {
  func testHTTPMethodRawValues() {
    XCTAssertEqual(HTTPMethod.GET.rawValue, "GET")
    XCTAssertEqual(HTTPMethod.POST.rawValue, "POST")
    XCTAssertEqual(HTTPMethod.PUT.rawValue, "PUT")
    XCTAssertEqual(HTTPMethod.DELETE.rawValue, "DELETE")
    XCTAssertEqual(HTTPMethod.HEAD.rawValue, "HEAD")
    XCTAssertEqual(HTTPMethod.OPTIONS.rawValue, "OPTIONS")
    XCTAssertEqual(HTTPMethod.PATCH.rawValue, "PATCH")
  }

  func testHTTPMethodEquatable() {
    XCTAssertEqual(HTTPMethod.GET, HTTPMethod.GET)
    XCTAssertEqual(HTTPMethod.GET, HTTPMethod(rawValue: "GET"))
    XCTAssertNotEqual(HTTPMethod.GET, HTTPMethod.POST)
  }

  func testHTTPMethodCustomRawValue() {
    let custom = HTTPMethod(rawValue: "CONNECT")
    XCTAssertEqual(custom.rawValue, "CONNECT")
    XCTAssertNotEqual(custom, HTTPMethod.GET)
  }

  func testHTTPResponseStatusPresets() {
    XCTAssertEqual(HTTPResponseStatus.ok.code, 200)
    XCTAssertEqual(HTTPResponseStatus.ok.reasonPhrase, "OK")
    XCTAssertEqual(HTTPResponseStatus.imATeapot.code, 418)
    XCTAssertEqual(HTTPResponseStatus.imATeapot.reasonPhrase, "I'm a teapot")
  }

  func testHTTPResponseStatusCustom() {
    let notFound = HTTPResponseStatus(code: 404, reasonPhrase: "Not Found")
    XCTAssertEqual(notFound.code, 404)
    XCTAssertEqual(notFound.reasonPhrase, "Not Found")
  }

  func testHTTPVersionEquatable() {
    XCTAssertEqual(HTTPVersion.http1_1, HTTPVersion.http1_1)
    XCTAssertNotEqual(HTTPVersion.http1_1, HTTPVersion.http2)
  }
}

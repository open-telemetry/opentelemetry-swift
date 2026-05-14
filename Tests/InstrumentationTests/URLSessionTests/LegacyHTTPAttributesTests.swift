/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import URLSessionInstrumentation
import XCTest

final class LegacyHTTPAttributesTests: XCTestCase {
  // The literal wire keys exposed by the .old / .httpDup semantic convention.
  // These are pinned to the OTel v0 HTTP spec and must not change — backends
  // and dashboards depending on the legacy convention key on these exact
  // strings.
  func testRawValuesMatchOTelV0Keys() {
    XCTAssertEqual(LegacyHTTPAttributes.method.rawValue, "http.method")
    XCTAssertEqual(LegacyHTTPAttributes.url.rawValue, "http.url")
    XCTAssertEqual(LegacyHTTPAttributes.target.rawValue, "http.target")
    XCTAssertEqual(LegacyHTTPAttributes.scheme.rawValue, "http.scheme")
    XCTAssertEqual(LegacyHTTPAttributes.statusCode.rawValue, "http.status_code")
    XCTAssertEqual(LegacyHTTPAttributes.netPeerName.rawValue, "net.peer.name")
    XCTAssertEqual(LegacyHTTPAttributes.netPeerPort.rawValue, "net.peer.port")
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import OpenTelemetryProtocolExporterHttp
import SharedTestUtils
import XCTest

final class HTTPClientAsyncTests: XCTestCase {
  var testServer: HttpTestServer!

  override func setUp() {
    testServer = HttpTestServer()
    XCTAssertNoThrow(try testServer.start())
  }

  override func tearDown() {
    XCTAssertNoThrow(try testServer.stop())
  }

  func testBaseHTTPClientAsyncSendSuccess() async throws {
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)/some-route")!
    let httpClient = BaseHTTPClient()
    var request = URLRequest(url: endpoint)
    request.httpMethod = HTTPMethod.GET.rawValue

    let response = try await httpClient.send(request: request)
    XCTAssertEqual(HTTPResponseStatus.ok.code, UInt(response.statusCode))

    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      XCTAssertEqual(head.version, .http1_1)
      XCTAssertEqual(head.method.rawValue, "GET")
      XCTAssertEqual(head.uri, "/some-route")
    })
    XCTAssertNoThrow(try testServer.receiveEnd())
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import URLSessionInstrumentation
import XCTest

final class ResponsePayloadRecordingModeTests: XCTestCase {
  func testDefaultModeRecordsSuccessfulHTTPResponse() {
    let configuration = URLSessionInstrumentationConfiguration()
    let response = makeHTTPResponse(statusCode: 200)

    XCTAssertTrue(configuration.responsePayloadRecordingMode.shouldRecordPayload(for: response))
  }

  func testHTTPErrorOnlyRecordsErrorResponses() {
    for statusCode in [400, 500, 599] {
      let response = makeHTTPResponse(statusCode: statusCode)

      XCTAssertTrue(ResponsePayloadRecordingMode.httpErrorsOnly.shouldRecordPayload(for: response))
    }
  }

  func testHTTPErrorOnlyDoesNotRecordNonErrorResponses() {
    for statusCode in [200, 399, 600] {
      let response = makeHTTPResponse(statusCode: statusCode)

      XCTAssertFalse(ResponsePayloadRecordingMode.httpErrorsOnly.shouldRecordPayload(for: response))
    }
  }

  func testHTTPErrorOnlyDoesNotRecordNonHTTPResponse() {
    let response = URLResponse(url: URL(string: "file:///payload")!,
                               mimeType: nil,
                               expectedContentLength: 0,
                               textEncodingName: nil)

    XCTAssertFalse(ResponsePayloadRecordingMode.httpErrorsOnly.shouldRecordPayload(for: response))
  }

  private func makeHTTPResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "https://example.com")!,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil)!
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

final class NetworkSpanTests: XCTestCase {
  private static let urlSessionScope = "NSURLSession"

  // Only the requests the scenario makes against the status server's
  // /status/<code> endpoints; the app also talks to the real Hacker News API.
  private var statusSpans: [ExportedSpan] {
    OTLPOutput.spans.filter {
      $0.scope.name == Self.urlSessionScope
        && $0.span.attributes.string("http.target")?.hasPrefix("/status/") == true
    }
  }

  private func span(forStatus code: Int64) throws -> ProtoSpan {
    try XCTUnwrap(statusSpans.first { $0.span.attributes.string("http.target") == "/status/\(code)" }?.span,
                  "missing HTTP span for /status/\(code)")
  }

  func testOneSpanPerScenarioRequest() {
    XCTAssertEqual(statusSpans.count, Scenario.statusCodes.count,
                   "expected one span per status request, got \(statusSpans.map { $0.span.attributes.string("http.url") ?? "?" })")
  }

  func testSpanAttributes() throws {
    for code in Scenario.statusCodes {
      let span = try span(forStatus: code)
      let attributes = span.attributes
      XCTAssertEqual(span.name, "HTTP GET")
      XCTAssertEqual(span.kind, .client)
      XCTAssertEqual(attributes.string("http.method"), "GET")
      XCTAssertEqual(attributes.string("http.scheme"), "http")
      XCTAssertEqual(attributes.string("net.peer.name"), "localhost")
      let port = try XCTUnwrap(attributes.int("net.peer.port"))
      XCTAssertEqual(attributes.string("http.url"), "http://localhost:\(port)/status/\(code)")
      XCTAssertEqual(attributes.int("http.status_code"), code)
      XCTAssertNotNil(attributes.int("http.response.body.size"))
      XCTAssertNotNil(attributes.string("network.connection.type"))
      XCTAssertNotNil(attributes.string("session.id"))
    }
  }

  func testSpanStatusReflectsHTTPStatus() throws {
    let ok = try span(forStatus: 200)
    XCTAssertEqual(ok.status.code, .unset)
    XCTAssertTrue(ok.status.message.isEmpty)

    let notFound = try span(forStatus: 404)
    XCTAssertEqual(notFound.status.code, .error)
    XCTAssertEqual(notFound.status.message, "404")

    let serverError = try span(forStatus: 500)
    XCTAssertEqual(serverError.status.code, .error)
    XCTAssertEqual(serverError.status.message, "500")
  }

  func testExporterRequestsAreNotInstrumented() {
    let exportSpans = OTLPOutput.spans.filter {
      $0.scope.name == Self.urlSessionScope
        && $0.span.attributes.string("http.target")?.hasPrefix("/v1/") == true
    }
    XCTAssertTrue(exportSpans.isEmpty, "OTLP export requests must not produce spans")
  }
}

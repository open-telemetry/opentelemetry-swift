/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

final class NetworkSpanTests: XCTestCase {
  private static let urlSessionScope = "NSURLSession"

  // Only the requests the scenario makes against the status server's
  // /status/<code> endpoints.
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

/// The same /status/200, /status/404 and /status/500 requests from the
/// `main-stable` launch, which the runner configures with
/// `--httpSemanticConvention stable`.
final class StableNetworkSpanTests: XCTestCase {
  private static let urlSessionScope = "NSURLSession"

  private var stableOutput: OTLPOutput {
    OTLPOutput.launch(.mainStable)
  }

  /// Only the requests the scenario makes against the status server, now
  /// identified by the stable `url.path` key instead of `http.target`.
  private var statusSpans: [ExportedSpan] {
    stableOutput.spans.filter {
      $0.scope.name == Self.urlSessionScope
        && $0.span.attributes.string("url.path")?.hasPrefix("/status/") == true
    }
  }

  private func span(forStatus code: Int64) throws -> ProtoSpan {
    try XCTUnwrap(statusSpans.first { $0.span.attributes.string("url.path") == "/status/\(code)" }?.span,
                  "missing stable HTTP span for /status/\(code)")
  }

  func testOneSpanPerScenarioRequest() {
    XCTAssertEqual(statusSpans.count, Scenario.statusCodes.count,
                   "expected one span per status request, got \(statusSpans.map { $0.span.attributes.string("url.full") ?? "?" })")
  }

  func testSpanUsesStableAttributes() throws {
    for code in Scenario.statusCodes {
      let span = try span(forStatus: code)
      let attributes = span.attributes
      XCTAssertEqual(span.name, "GET")
      XCTAssertEqual(span.kind, .client)
      XCTAssertEqual(attributes.string("http.request.method"), "GET")
      XCTAssertEqual(attributes.string("url.scheme"), "http")
      XCTAssertEqual(attributes.string("server.address"), "localhost")
      let port = try XCTUnwrap(attributes.int("server.port"))
      XCTAssertEqual(attributes.string("url.full"), "http://localhost:\(port)/status/\(code)")
      XCTAssertEqual(attributes.string("url.path"), "/status/\(code)")
      XCTAssertEqual(attributes.int("http.response.status_code"), code)
      XCTAssertNotNil(attributes.int("http.response.body.size"))
      XCTAssertNotNil(attributes.string("network.connection.type"))
      XCTAssertNotNil(attributes.string("session.id"))

      // Pure stable mode must not emit the legacy HTTP/network keys.
      XCTAssertNil(attributes.string("http.method"))
      XCTAssertNil(attributes.string("http.url"))
      XCTAssertNil(attributes.string("http.target"))
      XCTAssertNil(attributes.string("http.scheme"))
      XCTAssertNil(attributes.string("net.peer.name"))
      XCTAssertNil(attributes.int("net.peer.port"))
      XCTAssertNil(attributes.int("http.status_code"))
    }
  }

  func testSpanStatusAndErrorType() throws {
    let ok = try span(forStatus: 200)
    XCTAssertEqual(ok.status.code, .unset)
    XCTAssertTrue(ok.status.message.isEmpty)
    XCTAssertNil(ok.attributes.string("error.type"))

    for code in [Int64(404), 500] {
      let span = try span(forStatus: code)
      XCTAssertEqual(span.status.code, .error)
      XCTAssertTrue(span.status.message.isEmpty, "stable HTTP errors carry no status description")
      XCTAssertEqual(span.attributes.string("error.type"), String(code))
    }
  }

  func testExporterRequestsAreNotInstrumented() {
    let exportSpans = stableOutput.spans.filter {
      $0.scope.name == Self.urlSessionScope
        && $0.span.attributes.string("url.path")?.hasPrefix("/v1/") == true
    }
    XCTAssertTrue(exportSpans.isEmpty, "OTLP export requests must not produce spans")
  }
}

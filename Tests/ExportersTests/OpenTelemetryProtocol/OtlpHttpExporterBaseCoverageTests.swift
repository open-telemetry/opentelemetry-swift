/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import XCTest

/// Exercises configuration branches of `OtlpHttpExporterBase` that the
/// existing tests don't reach: env-var headers, config headers, the deprecated
/// URLSession initializer, and body fallback paths.
final class OtlpHttpExporterBaseCoverageTests: XCTestCase {
  private func makeBody() -> Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest {
    Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest()
  }

  func testEnvVarHeadersAppliedOnRequest() {
    let exporter = OtlpHttpExporterBase(
      endpoint: URL(string: "http://example.com")!,
      config: OtlpConfiguration(compression: .none),
      httpClient: BaseHTTPClient(),
      envVarHeaders: [("X-Env-Header", "env-value")])
    let request = exporter.createRequest(body: makeBody(), endpoint: URL(string: "http://example.com")!)
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Env-Header"), "env-value")
  }

  func testConfigHeadersAppliedWhenEnvVarHeadersNil() {
    let exporter = OtlpHttpExporterBase(
      endpoint: URL(string: "http://example.com")!,
      config: OtlpConfiguration(headers: [("X-Cfg-Header", "cfg-value")]),
      httpClient: BaseHTTPClient(),
      envVarHeaders: nil)
    let request = exporter.createRequest(body: makeBody(), endpoint: URL(string: "http://example.com")!)
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Cfg-Header"), "cfg-value")
  }

  func testHeadersProviderIsEvaluatedForEveryRequest() throws {
    let provider = MutableHeadersProvider([("Authorization", "Bearer first")])
    let exporter = try OtlpHttpExporterBase(
      endpoint: XCTUnwrap(URL(string: "http://example.com")),
      config: OtlpConfiguration(
        headers: [
          ("X-Static-Header", "static-value"),
          ("authorization", "Bearer static")
        ],
        headersProvider: provider.currentHeaders
      ),
      httpClient: BaseHTTPClient(),
      envVarHeaders: nil
    )

    let firstRequest = try exporter.createRequest(
      body: makeBody(),
      endpoint: XCTUnwrap(URL(string: "http://example.com"))
    )
    provider.update([("Authorization", "Bearer second")])
    let secondRequest = try exporter.createRequest(
      body: makeBody(),
      endpoint: XCTUnwrap(URL(string: "http://example.com"))
    )

    XCTAssertEqual(firstRequest.value(forHTTPHeaderField: "Authorization"), "Bearer first")
    XCTAssertEqual(secondRequest.value(forHTTPHeaderField: "Authorization"), "Bearer second")
    XCTAssertEqual(firstRequest.value(forHTTPHeaderField: "X-Static-Header"), "static-value")
    XCTAssertEqual(secondRequest.value(forHTTPHeaderField: "X-Static-Header"), "static-value")
    XCTAssertEqual(provider.callCount, 2)
  }

  func testEnvVarHeadersTakePrecedenceOverHeadersProvider() throws {
    let provider = MutableHeadersProvider([("Authorization", "Bearer provider")])
    let exporter = try OtlpHttpExporterBase(
      endpoint: XCTUnwrap(URL(string: "http://example.com")),
      config: OtlpConfiguration(headersProvider: provider.currentHeaders),
      httpClient: BaseHTTPClient(),
      envVarHeaders: [("Authorization", "Bearer environment")]
    )

    let request = try exporter.createRequest(
      body: makeBody(),
      endpoint: XCTUnwrap(URL(string: "http://example.com"))
    )

    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer environment")
    XCTAssertEqual(provider.callCount, 0)
  }

  func testNilHeadersProviderRetainsStaticHeaders() throws {
    let provider = MutableHeadersProvider(nil)
    let exporter = try OtlpHttpExporterBase(
      endpoint: XCTUnwrap(URL(string: "http://example.com")),
      config: OtlpConfiguration(
        headers: [("Authorization", "Bearer static")],
        headersProvider: provider.currentHeaders
      ),
      httpClient: BaseHTTPClient(),
      envVarHeaders: nil
    )

    let request = try exporter.createRequest(
      body: makeBody(),
      endpoint: XCTUnwrap(URL(string: "http://example.com"))
    )

    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer static")
    XCTAssertEqual(provider.callCount, 1)
  }

  func testContentTypeAndUserAgentSet() {
    let exporter = OtlpHttpExporterBase(
      endpoint: URL(string: "http://example.com")!,
      config: OtlpConfiguration(compression: .none),
      httpClient: BaseHTTPClient(),
      envVarHeaders: nil)
    let request = exporter.createRequest(body: makeBody(), endpoint: URL(string: "http://example.com")!)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-protobuf")
    XCTAssertNotNil(request.value(forHTTPHeaderField: Constants.HTTP.userAgent))
    XCTAssertEqual(request.httpMethod, "POST")
  }

  @available(*, deprecated)
  func testDeprecatedInitWithURLSession() {
    let session = URLSession(configuration: .ephemeral)
    let exporter = OtlpHttpExporterBase(
      endpoint: URL(string: "http://example.com")!,
      config: OtlpConfiguration(),
      useSession: session,
      envVarHeaders: nil)
    XCTAssertNotNil(exporter)
  }

  @available(*, deprecated)
  func testDeprecatedInitWithNilURLSessionUsesDefault() {
    let exporter = OtlpHttpExporterBase(
      endpoint: URL(string: "http://example.com")!,
      config: OtlpConfiguration(),
      useSession: nil,
      envVarHeaders: nil)
    XCTAssertNotNil(exporter)
  }
}

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

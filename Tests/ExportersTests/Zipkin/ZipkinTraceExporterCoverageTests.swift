/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import ZipkinExporter
import XCTest

final class ZipkinTraceExporterCoverageTests: XCTestCase {
  func testFlushReturnsSuccess() {
    let exporter = ZipkinTraceExporter(options: ZipkinTraceExporterOptions(endpoint: "http://localhost:9411/api/v2/spans"))
    XCTAssertEqual(exporter.flush(), .success)
  }

  func testShutdownRunsWithoutError() {
    let exporter = ZipkinTraceExporter(options: ZipkinTraceExporterOptions(endpoint: "http://localhost:9411/api/v2/spans"))
    exporter.shutdown()
  }

  func testExportHandlesInvalidEndpoint() {
    // Invalid URL → export returns .failure early (before any network call).
    let options = ZipkinTraceExporterOptions(endpoint: "not a url")
    let exporter = ZipkinTraceExporter(options: options)
    let result = exporter.export(spans: [ZipkinSpanConverterTests.createTestSpan()])
    XCTAssertEqual(result, .failure)
  }

  func testExportWithAdditionalHeadersProducesRequest() {
    // Even when the export ultimately fails against an unroutable host, the
    // request-construction path with additional headers is exercised.
    let options = ZipkinTraceExporterOptions(
      endpoint: "http://127.0.0.1:1/api/v2/spans", // unbound port, fails fast
      timeoutSeconds: 0.2,
      additionalHeaders: ["X-Extra": "v"])
    let exporter = ZipkinTraceExporter(options: options)
    let result = exporter.export(spans: [ZipkinSpanConverterTests.createTestSpan()])
    XCTAssertEqual(result, .failure)
  }
}

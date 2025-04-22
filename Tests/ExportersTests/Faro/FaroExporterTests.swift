/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroExporterTests: XCTestCase {
  override func setUp() {
    super.setUp()
    FaroLoggingFactory.setLogger(logger: MockFaroLogger())
  }

  func testValidInitialization() throws {
    // Given
    let options = FaroExporterOptions(
      collectorUrl: "https://faro-collector.grafana.net/collect/123456",
      appName: "TestApp",
      appVersion: "1.0.0"
    )

    // When/Then
    XCTAssertNoThrow(try FaroExporter(options: options))
  }

  func testInvalidCollectorUrl() {
    // Given
    let options = FaroExporterOptions(
      collectorUrl: "",
      appName: "TestApp"
    )

    // When/Then
    XCTAssertThrowsError(try FaroExporter(options: options)) { error in
      XCTAssertEqual(error as? FaroExporterError, .invalidCollectorUrl)
    }
  }

  func testMissingApiKey() {
    // Given
    let options = FaroExporterOptions(
      collectorUrl: "https://faro-collector.grafana.net/collect/",
      appName: "TestApp"
    )

    // When/Then
    XCTAssertThrowsError(try FaroExporter(options: options)) { error in
      XCTAssertEqual(error as? FaroExporterError, .missingApiKey)
    }
  }

  func testOptionalParametersInitialization() throws {
    // Given
    let options = FaroExporterOptions(
      collectorUrl: "https://faro-collector.grafana.net/collect/123456",
      appName: nil,
      appVersion: nil,
      appEnvironment: nil,
      namespace: nil
    )

    // When
    let exporter = try FaroExporter(options: options)

    // Then
    XCTAssertNotNil(exporter)
  }
}

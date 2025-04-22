/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroManagerFactoryTests: XCTestCase {
  // Test that the factory returns the same instance when called multiple times with the same options
  func testGetInstanceReturnsSameInstance() throws {
    // Given
    let options = FaroExporterOptions(
      collectorUrl: "https://faro-collector.grafana.net/collect/test-api-key",
      appName: "TestApp",
      appVersion: "1.0.0"
    )

    // When
    let instance1 = try FaroManagerFactory.getInstance(options: options)
    let instance2 = try FaroManagerFactory.getInstance(options: options)

    // Then
    XCTAssertTrue(instance1 === instance2, "Factory should return the same instance for the same options")
  }

  // Test that the factory returns different instances when called with different options
  func testGetInstanceReturnsDifferentInstancesWithDifferentOptions() throws {
    // Given
    let options1 = FaroExporterOptions(
      collectorUrl: "https://faro-collector.grafana.net/collect/test-api-key",
      appName: "TestApp1"
    )

    let options2 = FaroExporterOptions(
      collectorUrl: "https://faro-collector.grafana.net/collect/test-api-key",
      appName: "TestApp2"
    )

    // When
    let instance1 = try FaroManagerFactory.getInstance(options: options1)
    let instance2 = try FaroManagerFactory.getInstance(options: options2)

    // Then
    XCTAssertFalse(instance1 === instance2, "Factory should return different instances for different options")
  }

  // Test that options with the same values are considered equal
  func testSameOptionsAreEqual() throws {
    // Given
    let options1 = FaroExporterOptions(
      collectorUrl: "https://example.com/test-api-key",
      appName: "TestApp",
      appVersion: "1.0.0",
      appEnvironment: "test",
      namespace: "test-namespace"
    )

    let options2 = FaroExporterOptions(
      collectorUrl: "https://example.com/test-api-key",
      appName: "TestApp",
      appVersion: "1.0.0",
      appEnvironment: "test",
      namespace: "test-namespace"
    )

    // When
    let instance1 = try FaroManagerFactory.getInstance(options: options1)
    let instance2 = try FaroManagerFactory.getInstance(options: options2)

    // Then
    XCTAssertTrue(instance1 === instance2, "Factory should treat identical options as equal")
    XCTAssertEqual(options1, options2, "Options with same values should be equal")
  }
}

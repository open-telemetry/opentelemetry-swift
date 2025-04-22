/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroExporterOptionsTests: XCTestCase {
  // Test that options with same values are equal and have the same hash value
  func testHashableConformance() {
    // Given
    let options1 = FaroExporterOptions(
      collectorUrl: "https://example.com",
      appName: "TestApp",
      appVersion: "1.0.0",
      appEnvironment: "test",
      namespace: "test-namespace"
    )

    let options2 = FaroExporterOptions(
      collectorUrl: "https://example.com",
      appName: "TestApp",
      appVersion: "1.0.0",
      appEnvironment: "test",
      namespace: "test-namespace"
    )

    let options3 = FaroExporterOptions(
      collectorUrl: "https://different.com",
      appName: "TestApp",
      appVersion: "1.0.0",
      appEnvironment: "test",
      namespace: "test-namespace"
    )

    // Then
    XCTAssertEqual(options1, options2, "Options with same values should be equal")
    XCTAssertNotEqual(options1, options3, "Options with different values should not be equal")

    XCTAssertEqual(options1.hashValue, options2.hashValue, "Equal options should have the same hash value")
    XCTAssertNotEqual(options1.hashValue, options3.hashValue, "Different options should have different hash values")
  }

  // Test that options work correctly as dictionary keys
  func testOptionsDictionaryKey() {
    // Given
    let options1 = FaroExporterOptions(
      collectorUrl: "https://example.com/1",
      appName: "App1"
    )

    let options2 = FaroExporterOptions(
      collectorUrl: "https://example.com/2",
      appName: "App2"
    )

    // Create the same options as options1 to test equality as keys
    let options1Duplicate = FaroExporterOptions(
      collectorUrl: "https://example.com/1",
      appName: "App1"
    )

    // When
    var optionsDict = [FaroExporterOptions: String]()
    optionsDict[options1] = "Instance 1"
    optionsDict[options2] = "Instance 2"

    // Then
    XCTAssertEqual(optionsDict.count, 2, "Dictionary should have 2 entries")
    XCTAssertEqual(optionsDict[options1], "Instance 1", "Should retrieve correct value for options1")
    XCTAssertEqual(optionsDict[options1Duplicate], "Instance 1", "Should retrieve same value with duplicate options")
    XCTAssertEqual(optionsDict[options2], "Instance 2", "Should retrieve correct value for options2")
  }

  // Test that nil values are handled correctly
  func testHashableWithNilValues() {
    // Given
    let options1 = FaroExporterOptions(
      collectorUrl: "https://example.com",
      appName: nil,
      appVersion: nil
    )

    let options2 = FaroExporterOptions(
      collectorUrl: "https://example.com",
      appName: nil,
      appVersion: nil
    )

    let options3 = FaroExporterOptions(
      collectorUrl: "https://example.com",
      appName: "TestApp",
      appVersion: nil
    )

    // Then
    XCTAssertEqual(options1, options2, "Options with same nil values should be equal")
    XCTAssertNotEqual(options1, options3, "Options with different nil values should not be equal")

    var optionsDict = [FaroExporterOptions: String]()
    optionsDict[options1] = "Instance 1"
    optionsDict[options3] = "Instance 3"

    XCTAssertEqual(optionsDict.count, 2, "Dictionary should have 2 entries")
    XCTAssertEqual(optionsDict[options2], "Instance 1", "Should retrieve same value with equal options")
  }
}

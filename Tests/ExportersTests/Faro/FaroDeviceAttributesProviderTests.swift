/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
@testable import FaroExporter

final class FaroDeviceAttributesProviderTests: XCTestCase {
  func testGetDeviceAttributesWithCustomValues() {
    // Given
    let source = MockDeviceInformationSource(
      osName: "macOS",
      osVersion: "14.0",
      deviceBrand: "MacBook",
      deviceModel: "MacBookPro18,1",
      isPhysical: false
    )
    let identifierProvider = MockPersistentDeviceIdentifierProvider(mockIdentifier: "custom-device-id")
    let provider = FaroDeviceAttributesProvider(source: source, identifierProvider: identifierProvider)

    // When
    let attributes = provider.getDeviceAttributes()

    // Then
    XCTAssertEqual(attributes["device_manufacturer"], "apple")
    XCTAssertEqual(attributes["device_os"], "macOS")
    XCTAssertEqual(attributes["device_os_version"], "14.0")
    XCTAssertEqual(attributes["device_os_detail"], "macOS 14.0")
    XCTAssertEqual(attributes["device_brand"], "MacBook")
    XCTAssertEqual(attributes["device_model"], "MacBookPro18,1")
    XCTAssertEqual(attributes["device_id"], "custom-device-id")
    XCTAssertEqual(attributes["device_is_physical"], "false")
  }

  func testGetDeviceAttributesContainsAllRequiredKeys() {
    // Given
    let source = MockDeviceInformationSource(
      osName: "macOS",
      osVersion: "14.0",
      deviceBrand: "MacBook",
      deviceModel: "MacBookPro18,1",
      isPhysical: false
    )
    let identifierProvider = MockPersistentDeviceIdentifierProvider(mockIdentifier: "custom-device-id")
    let provider = FaroDeviceAttributesProvider(source: source, identifierProvider: identifierProvider)

    // When
    let attributes = provider.getDeviceAttributes()

    // Then
    let requiredKeys = [
      "device_manufacturer",
      "device_os",
      "device_os_version",
      "device_os_detail",
      "device_brand",
      "device_model",
      "device_id",
      "device_is_physical"
    ]

    for key in requiredKeys {
      XCTAssertNotNil(attributes[key], "Missing required key: \(key)")
    }
  }
}

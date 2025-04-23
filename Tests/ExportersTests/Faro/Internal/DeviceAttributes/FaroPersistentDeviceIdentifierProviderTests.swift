/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroPersistentDeviceIdentifierProviderTests: XCTestCase {
  private var mockStorage: MockUserDefaults!
  private var sut: FaroPersistentDeviceIdentifierProvider!
  private let deviceIdKey = "faro.device_id"

  override func setUp() {
    super.setUp()
    mockStorage = MockUserDefaults()
    sut = FaroPersistentDeviceIdentifierProvider(storage: mockStorage)
  }

  override func tearDown() {
    mockStorage = nil
    sut = nil
    super.tearDown()
  }

  func testGetIdentifier_WhenNoExistingId_CreatesAndStoresNewId() {
    // Given
    XCTAssertNil(mockStorage.string(forKey: deviceIdKey))

    // When
    let identifier = sut.getIdentifier()

    // Then
    XCTAssertFalse(identifier.isEmpty)
    XCTAssertNotNil(UUID(uuidString: identifier))
    XCTAssertEqual(mockStorage.string(forKey: deviceIdKey), identifier)
  }

  func testGetIdentifier_WhenExistingId_ReturnsSameId() {
    // Given
    let existingId = UUID().uuidString
    mockStorage.set(existingId, forKey: deviceIdKey)

    // When
    let identifier = sut.getIdentifier()

    // Then
    XCTAssertEqual(identifier, existingId)
  }

  func testGetIdentifier_MultipleCalls_ReturnsSameId() {
    // When
    let firstIdentifier = sut.getIdentifier()
    let secondIdentifier = sut.getIdentifier()
    let thirdIdentifier = sut.getIdentifier()

    // Then
    XCTAssertEqual(firstIdentifier, secondIdentifier)
    XCTAssertEqual(secondIdentifier, thirdIdentifier)
  }
}

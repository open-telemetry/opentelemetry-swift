/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroSessionManagerTests: XCTestCase {
  private var sut: FaroSessionManager!
  private var mockDateProvider: MockDateProvider!
  private var mockDeviceAttributesProvider: MockDeviceAttributesProvider!

  override func setUp() {
    super.setUp()
    mockDateProvider = MockDateProvider()
    mockDeviceAttributesProvider = MockDeviceAttributesProvider()
    sut = FaroSessionManager(
      dateProvider: mockDateProvider,
      deviceAttributesProvider: mockDeviceAttributesProvider
    )
  }

  override func tearDown() {
    sut = nil
    mockDateProvider = nil
    mockDeviceAttributesProvider = nil
    super.tearDown()
  }

  func testInitSessionManager() {
    // Then
    let session = sut.getSession()
    XCTAssertNotNil(session.id)
    XCTAssertFalse(session.id.isEmpty)
    XCTAssertEqual(session.attributes, mockDeviceAttributesProvider.mockAttributes)
  }

  func testSessionExpiresAfterMaxLifetime() {
    // Given
    let initialSession = sut.getSession()

    // When - advance time beyond the 4-hour max lifetime
    mockDateProvider.advance(by: 4 * 60 * 60 + 1) // 4 hours + 1 second

    // Then
    let newSession = sut.getSession()
    XCTAssertNotEqual(initialSession.id, newSession.id)
  }

  func testSessionExpiresAfterInactivity() {
    // Given
    let initialSession = sut.getSession()

    // When - advance time beyond the 15-minute inactivity limit
    mockDateProvider.advance(by: 15 * 60 + 1) // 15 minutes + 1 second

    // Then
    let newSession = sut.getSession()
    XCTAssertNotEqual(initialSession.id, newSession.id)
  }

  func testSessionRemainsValidWithinTimeConstraints() {
    // Given
    let initialSession = sut.getSession()

    // When - advance time but stay within limits
    mockDateProvider.advance(by: 14 * 60) // 14 minutes

    // Then
    let newSession = sut.getSession()
    XCTAssertEqual(initialSession.id, newSession.id)
  }

  func testUpdateLastActivity() {
    // Given
    let initialSession = sut.getSession()

    // When - advance time close to inactivity limit
    mockDateProvider.advance(by: 14 * 60) // 14 minutes

    // Update last activity
    let activityDate = mockDateProvider.currentDate()
    sut.updateLastActivity(date: activityDate)

    // Advance again close to the limit from the new activity time
    mockDateProvider.advance(by: 14 * 60) // Another 14 minutes

    // Then
    let newSession = sut.getSession()
    XCTAssertEqual(initialSession.id, newSession.id) // Session should still be valid
  }

  func testUpdateLastActivityWithOlderDate() {
    // Given
    let initialDate = mockDateProvider.currentDate()
    let initialSession = sut.getSession()

    // When - advance time
    mockDateProvider.advance(by: 5 * 60) // 5 minutes

    // Try to update with an older date
    sut.updateLastActivity(date: initialDate)

    // Advance time close to inactivity limit from the current time
    mockDateProvider.advance(by: 14 * 60) // 14 minutes

    // Then - session should expire because the older date was ignored
    let newSession = sut.getSession()
    XCTAssertNotEqual(initialSession.id, newSession.id)
  }

  func testOnSessionIdChangedCallback() {
    // Given
    var oldSessionId: String?
    var newSessionId: String?
    sut.onSessionIdChanged = { old, new in
      oldSessionId = old
      newSessionId = new
    }

    let initialSession = sut.getSession()

    // When - advance time beyond the max lifetime
    mockDateProvider.advance(by: 4 * 60 * 60 + 1) // 4 hours + 1 second

    // Force session refresh
    let newSession = sut.getSession()

    // Then
    XCTAssertEqual(oldSessionId, initialSession.id)
    XCTAssertEqual(newSessionId, newSession.id)
  }
}

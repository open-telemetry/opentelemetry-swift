/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import XCTest
@testable import FaroExporter

final class FaroSessionManagerTests: XCTestCase {
    private var sut: FaroSessionManager!
    private var dateProvider: MockDateProvider!
    private let initialDate = Date(timeIntervalSince1970: 0) // 1970-01-01 for predictable testing
    
    override func setUp() {
        super.setUp()
        dateProvider = MockDateProvider(initialDate: initialDate)
        sut = FaroSessionManager(dateProvider: dateProvider)
    }
    
    override func tearDown() {
        sut = nil
        dateProvider = nil
        super.tearDown()
    }
    
    // MARK: - Session Management Tests
    
    func testGetSessionIdReturnsNonEmptyString() {
        // When
        let sessionId = sut.getSessionId()
        
        // Then
        XCTAssertFalse(sessionId.isEmpty, "Session ID should not be empty")
    }
    
    func testGetSessionIdReturnsSameIdWithinFourHours() {
        // Given
        let initialSessionId = sut.getSessionId()
        
        // When - advance time by 3 hours and 59 minutes
        let threeHoursAndFiftyNineMinutes: TimeInterval = 4 * 60 * 60 - 60
        dateProvider.advance(by: threeHoursAndFiftyNineMinutes)
        let laterSessionId = sut.getSessionId()
        
        // Then
        XCTAssertEqual(initialSessionId, laterSessionId, "Session ID should remain the same within 4 hours")
    }
    
    func testGetSessionIdReturnsNewIdAfterFourHours() {
        // Given
        let initialSessionId = sut.getSessionId()
        
        // When - advance time by 4 hours and 1 minute
        let fourHoursAndOneMinute: TimeInterval = 4 * 60 * 60 + 60
        dateProvider.advance(by: fourHoursAndOneMinute)
        let newSessionId = sut.getSessionId()
        
        // Then
        XCTAssertNotEqual(initialSessionId, newSessionId, "Session ID should change after 4 hours")
    }
    
    func testOnSessionIdChangedNotCalledOnInitialization() {
        // Given
        var callCount = 0
        sut.onSessionIdChanged = { (_, _) in
            callCount += 1
        }
        
        // When
        _ = sut.getSessionId()
        
        // Then
        XCTAssertEqual(callCount, 0, "Callback should not be called on initialization")
    }
    
    func testOnSessionIdChangedCalledWhenSessionRefreshed() {
        // Given
        var capturedPreviousId: String?
        var capturedNewId: String?
        sut.onSessionIdChanged = { (previousId: String, newId: String) in
            capturedPreviousId = previousId
            capturedNewId = newId
        }
        let initialSessionId = sut.getSessionId()
        
        // When - advance time by 4 hours and 1 minute to trigger session expiration
        let fourHoursAndOneMinute: TimeInterval = 4 * 60 * 60 + 60
        dateProvider.advance(by: fourHoursAndOneMinute)
        let newSessionId = sut.getSessionId()
        
        // Then
        XCTAssertEqual(capturedPreviousId, initialSessionId, "Previous session ID should be the initial ID")
        XCTAssertEqual(capturedNewId, newSessionId, "New session ID should be the refreshed ID")
        XCTAssertNotEqual(capturedPreviousId, capturedNewId, "Session IDs should be different")
    }
    
    func testOnSessionIdChangedNotCalledWhenSessionStillValid() {
        // Given
        var callCount = 0
        sut.onSessionIdChanged = { (previousId: String, newId: String) in
            callCount += 1
        }
        _ = sut.getSessionId() // Get initial session
        
        // When - advance time by less than expiration (3 hours)
        let threeHours: TimeInterval = 3 * 60 * 60
        dateProvider.advance(by: threeHours)
        _ = sut.getSessionId() // Check if session is still valid
        
        // Then
        XCTAssertEqual(callCount, 0, "Callback should not be called when session hasn't expired")
    }
} 
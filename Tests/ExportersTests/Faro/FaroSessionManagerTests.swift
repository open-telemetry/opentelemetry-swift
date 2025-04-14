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
    
    func test_getSessionId_returnsNonEmptyString() {
        // When
        let sessionId = sut.getSessionId()
        
        // Then
        XCTAssertFalse(sessionId.isEmpty, "Session ID should not be empty")
    }
    
    func test_getSessionId_returnsSameIdWithinFourHours() {
        // Given
        let initialSessionId = sut.getSessionId()
        
        // When - advance time by 3 hours and 59 minutes
        let threeHoursAndFiftyNineMinutes: TimeInterval = 4 * 60 * 60 - 60
        dateProvider.advance(by: threeHoursAndFiftyNineMinutes)
        let laterSessionId = sut.getSessionId()
        
        // Then
        XCTAssertEqual(initialSessionId, laterSessionId, "Session ID should remain the same within 4 hours")
    }
    
    func test_getSessionId_returnsNewIdAfterFourHours() {
        // Given
        let initialSessionId = sut.getSessionId()
        
        // When - advance time by 4 hours and 1 minute
        let fourHoursAndOneMinute: TimeInterval = 4 * 60 * 60 + 60
        dateProvider.advance(by: fourHoursAndOneMinute)
        let newSessionId = sut.getSessionId()
        
        // Then
        XCTAssertNotEqual(initialSessionId, newSessionId, "Session ID should change after 4 hours")
    }
} 
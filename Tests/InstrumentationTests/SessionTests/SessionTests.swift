import XCTest
@testable import Sessions
@testable import OpenTelemetrySdk

final class SessionTests: XCTestCase {
  func testSessionInitialization() {
    let id = "test-session-id"
    let expireTime = Date(timeIntervalSinceNow: 1800) // 30 minutes from now

    let session = Session(id: id, expireTime: expireTime)

    XCTAssertEqual(session.id, id)
    XCTAssertEqual(session.expireTime, expireTime)
    XCTAssertNil(session.previousId, "Default initialization should have nil previousId")
    XCTAssertLessThanOrEqual(Date().timeIntervalSince(session.startTime), 1.0, "Start time should be set to current time by default")
  }

  func testSessionEquality() {
    let id = "test-session-id"
    let expireTime = Date()
    let startTime = Date()
    let previousId = "prev-id"

    let session1 = Session(id: id, expireTime: expireTime, previousId: previousId, startTime: startTime)
    let session2 = Session(id: id, expireTime: expireTime, previousId: previousId, startTime: startTime)

    XCTAssertEqual(session1, session2, "Sessions with same ID, expireTime, startTime, and previousId should be equal")
  }

  func testSessionInequality() {
    let expireTime = Date()
    let session1 = Session(id: "session-1", expireTime: expireTime)
    let session2 = Session(id: "session-2", expireTime: expireTime)

    XCTAssertNotEqual(session1, session2, "Sessions with different IDs should not be equal")
  }

  func testSessionNotExpired() {
    let futureExpiry = Date(timeIntervalSinceNow: 1800) // 30 minutes from now
    let session = Session(id: "test-id", expireTime: futureExpiry)

    XCTAssertFalse(session.isExpired(), "Session with future expireTime should not be expired")
  }

  func testSessionExpired() {
    let pastExpiry = Date(timeIntervalSinceNow: -1800) // 30 minutes ago
    let session = Session(id: "test-id", expireTime: pastExpiry)

    XCTAssertTrue(session.isExpired(), "Session with past expireTime should be expired")
  }

  func testSessionExpiryAtExactTime() {
    let currentTime = Date()
    let session = Session(id: "test-id", expireTime: currentTime)

    // Sleep briefly to ensure current time is past expiry
    Thread.sleep(forTimeInterval: 0.001)

    XCTAssertTrue(session.isExpired(), "Session expiring at current time should be considered expired")
  }

  func testSessionWithPreviousId() {
    let id = "current-session"
    let previousId = "previous-session"
    let expireTime = Date(timeIntervalSinceNow: 1800)

    let session = Session(id: id, expireTime: expireTime, previousId: previousId)

    XCTAssertEqual(session.id, id)
    XCTAssertEqual(session.previousId, previousId)
    XCTAssertEqual(session.expireTime, expireTime)
  }
  
  func testEndTimeForActiveSession() {
    let session = Session(id: "test-id", expireTime: Date(timeIntervalSinceNow: 1800))
    XCTAssertNil(session.endTime, "Active session should have nil endTime")
  }
  
  func testEndTimeForExpiredSession() {
    let session = Session(id: "test-id", expireTime: Date(timeIntervalSinceNow: -1800), sessionTimeout: 1800)
    XCTAssertNotNil(session.endTime, "Expired session should have endTime")
  }
  
  func testDurationForActiveSession() {
    let session = Session(id: "test-id", expireTime: Date(timeIntervalSinceNow: 1800))
    XCTAssertNil(session.duration, "Active session should have nil duration")
  }
  
  func testDurationForExpiredSession() {
    let session = Session(id: "test-id", expireTime: Date(timeIntervalSinceNow: -1800), sessionTimeout: 1800)
    XCTAssertNotNil(session.duration, "Expired session should have duration")
  }
  
  func testSafeUnwrappingInComputedProperties() {
    // Test that endTime and duration don't crash with force unwrapping
    let expiredSession = Session(id: "test-id", expireTime: Date(timeIntervalSinceNow: -1800), sessionTimeout: 1800)
    let activeSession = Session(id: "test-id", expireTime: Date(timeIntervalSinceNow: 1800))
    
    // These should not crash
    _ = expiredSession.endTime
    _ = expiredSession.duration
    _ = activeSession.endTime
    _ = activeSession.duration
    
    XCTAssertNotNil(expiredSession.endTime)
    XCTAssertNotNil(expiredSession.duration)
    XCTAssertNil(activeSession.endTime)
    XCTAssertNil(activeSession.duration)
  }
}
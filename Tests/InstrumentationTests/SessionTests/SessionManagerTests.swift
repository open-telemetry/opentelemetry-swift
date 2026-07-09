import XCTest
@testable import Sessions

final class SessionManagerTests: XCTestCase {
  var sessionManager: SessionManager!

  override func setUp() {
    super.setUp()
    SessionStore.teardown()
    sessionManager = SessionManager()
  }

  override func tearDown() {
    NotificationCenter.default.removeObserver(self)
    SessionStore.teardown()
    super.tearDown()
  }

  func testGetSession() {
    let session = sessionManager.getSession()
    XCTAssertNotNil(session)
    XCTAssertNotNil(session.id)
    XCTAssertNotNil(session.expireTime)
    XCTAssertNil(session.previousId)
  }

  func testGetSessionId() {
    let id1 = sessionManager.getSession().id
    let id2 = sessionManager.getSession().id
    XCTAssertEqual(id1, id2)
  }

  func testGetSessionRenewed() {
    let t1 = sessionManager.getSession().expireTime
    let t2 = sessionManager.getSession().expireTime
    XCTAssertGreaterThan(t2, t1)
  }

  func testStartTimePreservedWhenSessionExtended() {
    let originalSession = sessionManager.getSession()
    Thread.sleep(forTimeInterval: 0.1)
    let extendedSession = sessionManager.getSession()

    XCTAssertEqual(originalSession.id, extendedSession.id)
    XCTAssertGreaterThan(extendedSession.expireTime, originalSession.expireTime)
    XCTAssertEqual(originalSession.startTime, extendedSession.startTime)
  }

  func testGetSessionExpired() {
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 0))
    let session1 = sessionManager.getSession()
    Thread.sleep(forTimeInterval: 0.1)
    let session2 = sessionManager.getSession()

    XCTAssertNotEqual(session1.id, session2.id)
    XCTAssertNotEqual(session1.startTime, session2.startTime)
    XCTAssertGreaterThan(session2.startTime, session1.startTime)
  }

  func testGetSessionExpiredByMaxLifetime() {
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 60 * 60, maxLifetime: 0))
    let session1 = sessionManager.getSession()
    let session2 = sessionManager.getSession()

    XCTAssertNotEqual(session1.id, session2.id)
    XCTAssertEqual(session2.previousId, session1.id)
    XCTAssertGreaterThan(session1.expireTime, Date())
  }

  func testGetSessionSavedToDisk() {
    let session = sessionManager.getSession()
    let savedId = UserDefaults.standard.object(forKey: SessionStore.idKey) as? String
    let savedTimeout = UserDefaults.standard.object(forKey: SessionStore.sessionTimeoutKey) as? Double

    XCTAssertEqual(session.id, savedId)
    XCTAssertEqual(session.sessionTimeout, TimeInterval(savedTimeout ?? -1))
  }

  func testRestorePersistedSessionFalseUsesPersistedSessionAsPreviousSession() {
    let persistedSession = Session(
      id: "persisted-session",
      expireTime: Date(timeIntervalSinceNow: 60 * 60),
      startTime: Date(),
      sessionTimeout: 60 * 60
    )
    SessionStore.saveImmediately(session: persistedSession)

    sessionManager = SessionManager(
      configuration: SessionConfig(sessionTimeout: 60 * 60, restorePersistedSession: false)
    )

    XCTAssertNil(sessionManager.peekSession())

    let newSession = sessionManager.getSession()
    XCTAssertNotEqual(newSession.id, persistedSession.id)
    XCTAssertEqual(newSession.previousId, persistedSession.id)
  }

  func testRestorePersistedSessionFalseEndsPersistedSessionAtLastActivity() {
    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = false
    defer {
      SessionEventInstrumentation.queue = []
      SessionEventInstrumentation.isApplied = false
    }
    let sessionTimeout: TimeInterval = 60 * 60
    let lastActivity = Date(timeIntervalSinceNow: -5 * 60)
    let persistedSession = Session(
      id: "persisted-session",
      expireTime: lastActivity.addingTimeInterval(sessionTimeout),
      startTime: Date(timeIntervalSinceNow: -2 * 60 * 60),
      sessionTimeout: sessionTimeout
    )
    SessionStore.saveImmediately(session: persistedSession)

    sessionManager = SessionManager(
      configuration: SessionConfig(sessionTimeout: sessionTimeout, restorePersistedSession: false)
    )

    let newSession = sessionManager.getSession()

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    guard SessionEventInstrumentation.queue.count >= 2 else {
      return
    }
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.id, persistedSession.id)
    if case .end = SessionEventInstrumentation.queue[0].eventType {
      XCTAssertEqual(SessionEventInstrumentation.queue[0].session.endTime?.timeIntervalSince1970 ?? 0, lastActivity.timeIntervalSince1970, accuracy: 1.0)
    } else {
      XCTFail("Expected a session.end event for the persisted session")
    }
    XCTAssertLessThanOrEqual(SessionEventInstrumentation.queue[0].session.endTime ?? .distantFuture, newSession.startTime)

    XCTAssertEqual(SessionEventInstrumentation.queue[1].session.id, newSession.id)
    if case .start = SessionEventInstrumentation.queue[1].eventType {
      return
    }
    XCTFail("Expected a session.start event for the new session")
  }

  func testLoadSessionMissingExpiry() {
    UserDefaults.standard.removeObject(forKey: SessionStore.expireTimeKey)
    UserDefaults.standard.set("test-id", forKey: SessionStore.idKey)
    UserDefaults.standard.set(Date(), forKey: SessionStore.startTimeKey)
    UserDefaults.standard.set(1800, forKey: SessionStore.sessionTimeoutKey)

    let loadedSession = SessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testLoadSessionMissingID() {
    let expiry1 = Date()
    UserDefaults.standard.set(expiry1, forKey: SessionStore.expireTimeKey)
    XCTAssertNil(SessionStore.load())

    let expiry2 = sessionManager.getSession().expireTime
    XCTAssertNotEqual(expiry1, expiry2)
  }

  func testPeekSessionWithoutSession() {
    XCTAssertNil(sessionManager.peekSession())
  }

  func testPeekSessionWithExistingSession() {
    let session = sessionManager.getSession()
    let peekedSession = sessionManager.peekSession()

    XCTAssertNotNil(peekedSession)
    XCTAssertEqual(peekedSession?.id, session.id)
  }

  func testPeekDoesNotExtendSession() {
    let originalSession = sessionManager.getSession()
    let peekedSession = sessionManager.peekSession()

    XCTAssertEqual(peekedSession?.expireTime, originalSession.expireTime)
  }

  func testCustomSessionLength() {
    let customLength: TimeInterval = 60
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: customLength))

    let session1 = sessionManager.getSession()
    let expectedExpiry = Date(timeIntervalSinceNow: Double(customLength))

    XCTAssertEqual(session1.expireTime.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 1.0)
    XCTAssertEqual(session1.sessionTimeout, customLength)
  }

  func testNewSessionHasNoPreviousId() {
    let session = sessionManager.getSession()
    XCTAssertNil(session.previousId)
  }

  func testExpiredSessionCreatesPreviousId() {
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 0))
    let firstSession = sessionManager.getSession()
    let secondSession = sessionManager.getSession()
    let thirdSession = sessionManager.getSession()

    XCTAssertNil(firstSession.previousId)
    XCTAssertEqual(secondSession.previousId, firstSession.id)
    XCTAssertEqual(thirdSession.previousId, secondSession.id)
  }

  func testStartSessionAddsToQueueWhenInstrumentationNotApplied() {
    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = false
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 0))
    let session = sessionManager.getSession()

    // Wait for async session event processing
    let expectation = XCTestExpectation(description: "Session event queued")
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now()) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 2.0)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.id, session.id)
  }

  func testStartSessionProcessesDirectlyWhenInstrumentationApplied() {
    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = true

    let session = sessionManager.getSession()

    // When instrumentation is applied, sessions are processed directly, not queued
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
    XCTAssertNotNil(session.id)
  }

  func testSessionStartNotificationPosted() {
    let expectation = XCTestExpectation(description: "Session start notification")
    nonisolated(unsafe) var receivedSession: Session?

    let observer = NotificationCenter.default.addObserver(
      forName: SessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedSession = notification.object as? Session
      expectation.fulfill()
    }

    let session = sessionManager.getSession()

    wait(for: [expectation], timeout: 2.0) // Increased timeout for async processing
    XCTAssertEqual(receivedSession?.id, session.id)

    NotificationCenter.default.removeObserver(observer)
  }

  func testMultipleSessionStartNotifications() {
    // Clean up any existing state
    SessionStore.teardown()
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 0))

    nonisolated(unsafe) var receivedSessions: [String] = []
    let expectation = XCTestExpectation(description: "Multiple session notifications")
    expectation.expectedFulfillmentCount = 3

    let observer = NotificationCenter.default.addObserver(
      forName: SessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let session = notification.object as? Session {
        receivedSessions.append(session.id)
      }
      expectation.fulfill()
    }

    let session1 = sessionManager.getSession()
    let session2 = sessionManager.getSession()
    let session3 = sessionManager.getSession()

    wait(for: [expectation], timeout: 2.0)

    NotificationCenter.default.removeObserver(observer)

    // Only check the count and that we got the expected sessions
    XCTAssertEqual(receivedSessions.count, 3)
    XCTAssertTrue(receivedSessions.contains(session1.id))
    XCTAssertTrue(receivedSessions.contains(session2.id))
    XCTAssertTrue(receivedSessions.contains(session3.id))
  }
}

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

  func testGetSessionSavedToDisk() {
    let session = sessionManager.getSession()
    let savedId = UserDefaults.standard.object(forKey: SessionStore.idKey) as? String
    let savedTimeout = UserDefaults.standard.object(forKey: SessionStore.sessionTimeoutKey) as? Int

    XCTAssertEqual(session.id, savedId)
    XCTAssertEqual(session.sessionTimeout, savedTimeout)
  }

  func testLoadSessionMissingExpiry() {
    let id1 = "session-1"
    UserDefaults.standard.set(id1, forKey: SessionStore.idKey)
    XCTAssertNil(SessionStore.load())

    let id2 = sessionManager.getSession().id
    XCTAssertNotEqual(id1, id2)
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
    let customLength = 60
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

    let session = sessionManager.getSession()

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].id, session.id)
  }

  func testStartSessionTriggersNotificationWhenInstrumentationApplied() {
    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = true

    let expectation = XCTestExpectation(description: "Session notification posted")
    var receivedSession: Session?

    let observer = NotificationCenter.default.addObserver(
      forName: SessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedSession = notification.object as? Session
      expectation.fulfill()
    }

    let session = sessionManager.getSession()

    wait(for: [expectation], timeout: 0.1)

    XCTAssertNotNil(receivedSession)
    XCTAssertEqual(receivedSession?.id, session.id)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)

    NotificationCenter.default.removeObserver(observer)
  }
}
import XCTest
@testable import Sessions

final class SessionStoreTests: XCTestCase {
  override func tearDown() {
    SessionStore.teardown()
    super.tearDown()
  }

  func testSaveAndLoadSession() {
    let sessionId = "test-session-123"
    let expireTime = Date(timeIntervalSinceNow: 1800)
    let startTime = Date(timeIntervalSinceNow: -300)
    let session = Session(id: sessionId, expireTime: expireTime, previousId: nil, startTime: startTime)

    SessionStore.scheduleSave(session: session)
    let loadedSession = SessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertEqual(loadedSession?.expireTime, expireTime)
    XCTAssertEqual(loadedSession?.startTime, startTime)
    XCTAssertNil(loadedSession?.previousId)
  }

  func testLoadSessionWhenNothingSaved() {
    let loadedSession = SessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testLoadSessionMissingId() {
    UserDefaults.standard.set(Date(), forKey: SessionStore.expireTimeKey)
    UserDefaults.standard.set(Date(), forKey: SessionStore.startTimeKey)
    UserDefaults.standard.set(1800, forKey: SessionStore.sessionTimeoutKey)

    let loadedSession = SessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testLoadSessionMissingExpiry() {
    UserDefaults.standard.set("test-id", forKey: SessionStore.idKey)
    UserDefaults.standard.set(Date(), forKey: SessionStore.startTimeKey)
    UserDefaults.standard.set(1800, forKey: SessionStore.sessionTimeoutKey)

    let loadedSession = SessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testLoadSessionMissingStartTime() {
    UserDefaults.standard.set("test-id", forKey: SessionStore.idKey)
    UserDefaults.standard.set(Date(), forKey: SessionStore.expireTimeKey)
    UserDefaults.standard.set(1800, forKey: SessionStore.sessionTimeoutKey)

    let loadedSession = SessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testSaveOverwritesPreviousSession() {
    let session1 = Session(id: "session-1", expireTime: Date(), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    let session2 = Session(id: "session-2", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)

    SessionStore.saveImmediately(session: session1)
    let loaded1 = SessionStore.load()
    XCTAssertEqual(loaded1?.id, "session-1")

    SessionStore.saveImmediately(session: session2)
    let loaded2 = SessionStore.load()
    XCTAssertEqual(loaded2?.id, "session-2")
  }

  func testStoreKeys() {
    XCTAssertEqual(SessionStore.idKey, "otel-session-id")
    XCTAssertEqual(SessionStore.expireTimeKey, "otel-session-expire-time")
    XCTAssertEqual(SessionStore.startTimeKey, "otel-session-start-time")
    XCTAssertEqual(SessionStore.previousIdKey, "otel-session-previous-id")
    XCTAssertEqual(SessionStore.sessionTimeoutKey, "otel-session-timeout")
  }

  func testLoadWithCorruptedData() {
    UserDefaults.standard.set(123, forKey: SessionStore.idKey)
    UserDefaults.standard.set("invalid-date", forKey: SessionStore.expireTimeKey)

    let loadedSession = SessionStore.load()
    XCTAssertNil(loadedSession)
  }

  func testSaveAndLoadSessionWithPreviousId() {
    let sessionId = "current-session-123"
    let previousId = "previous-session-456"
    let expireTime = Date(timeIntervalSinceNow: 1800)
    let session = Session(id: sessionId, expireTime: expireTime, previousId: previousId, startTime: Date(), sessionTimeout: 1800)

    SessionStore.scheduleSave(session: session)
    let loadedSession = SessionStore.load()

    XCTAssertNotNil(loadedSession)
    XCTAssertEqual(loadedSession?.id, sessionId)
    XCTAssertEqual(loadedSession?.previousId, previousId)
    XCTAssertEqual(loadedSession?.expireTime, expireTime)
  }

  func testScheduleSaveImmediatelySavesFirstSession() {
    let session = Session(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    SessionStore.scheduleSave(session: session)

    let savedId = UserDefaults.standard.string(forKey: SessionStore.idKey)
    XCTAssertEqual(savedId, session.id)
  }

  func testTeardownClearsUserDefaults() {
    let session = Session(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    SessionStore.saveImmediately(session: session)

    XCTAssertNotNil(UserDefaults.standard.string(forKey: SessionStore.idKey))

    SessionStore.teardown()

    XCTAssertNil(UserDefaults.standard.string(forKey: SessionStore.idKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: SessionStore.expireTimeKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: SessionStore.startTimeKey))
    XCTAssertNil(UserDefaults.standard.string(forKey: SessionStore.previousIdKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: SessionStore.sessionTimeoutKey))
  }

  func testTeardownInvalidatesTimer() {
    let session = Session(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date(), sessionTimeout: 1800)
    SessionStore.scheduleSave(session: session)

    SessionStore.teardown()

    let session2 = Session(id: "test-session-2", expireTime: Date(timeIntervalSinceNow: 1800), previousId: nil, startTime: Date())
    SessionStore.scheduleSave(session: session2)

    let savedId = UserDefaults.standard.string(forKey: SessionStore.idKey)
    XCTAssertEqual(savedId, session2.id)
  }
  
  func testLoadSessionMissingTimeout() {
    UserDefaults.standard.set("test-id", forKey: SessionStore.idKey)
    UserDefaults.standard.set(Date(), forKey: SessionStore.expireTimeKey)
    UserDefaults.standard.set(Date(), forKey: SessionStore.startTimeKey)
    
    let loadedSession = SessionStore.load()
    XCTAssertNil(loadedSession, "Session should be nil when timeout is missing")
  }
}
import XCTest
@testable import Sessions

final class SessionStoreTests: XCTestCase {
  private var suiteName: String!
  private var userDefaults: UserDefaults!
  private var persistence: UserDefaultsSessionPersistence!
  private var store: SessionStore!

  override func setUp() {
    super.setUp()
    suiteName = "io.opentelemetry.session-tests.\(UUID().uuidString)"
    userDefaults = UserDefaults(suiteName: suiteName)
    userDefaults.removePersistentDomain(forName: suiteName)
    persistence = UserDefaultsSessionPersistence(userDefaults: userDefaults, namespace: "test-session")
    store = SessionStore(persistence: persistence)
  }

  override func tearDown() {
    store.teardown()
    userDefaults.removePersistentDomain(forName: suiteName)
    store = nil
    persistence = nil
    userDefaults = nil
    suiteName = nil
    super.tearDown()
  }

  func testSaveAndLoadSession() {
    let session = Session(
      id: "test-session-123",
      expireTime: Date(timeIntervalSinceNow: 1800),
      startTime: Date(timeIntervalSinceNow: -300),
      maxLifetime: 4 * 60 * 60
    )

    store.scheduleSave(session: session)

    XCTAssertEqual(store.load(), session)
  }

  func testLoadSessionWhenNothingSaved() {
    XCTAssertNil(store.load())
  }

  func testLoadSessionMissingId() {
    userDefaults.set(Date(), forKey: persistence.expireTimeKey)
    userDefaults.set(Date(), forKey: persistence.startTimeKey)
    userDefaults.set(1800, forKey: persistence.sessionTimeoutKey)

    XCTAssertNil(store.load())
  }

  func testLoadSessionMissingExpiry() {
    userDefaults.set("test-id", forKey: persistence.idKey)
    userDefaults.set(Date(), forKey: persistence.startTimeKey)
    userDefaults.set(1800, forKey: persistence.sessionTimeoutKey)

    XCTAssertNil(store.load())
  }

  func testLoadSessionMissingStartTime() {
    userDefaults.set("test-id", forKey: persistence.idKey)
    userDefaults.set(Date(), forKey: persistence.expireTimeKey)
    userDefaults.set(1800, forKey: persistence.sessionTimeoutKey)

    XCTAssertNil(store.load())
  }

  func testSaveOverwritesPreviousSession() {
    let session1 = Session(id: "session-1", expireTime: Date(), startTime: Date())
    let session2 = Session(id: "session-2", expireTime: Date(timeIntervalSinceNow: 1800), startTime: Date())

    store.saveImmediately(session: session1)
    XCTAssertEqual(store.load()?.id, "session-1")

    store.saveImmediately(session: session2)
    XCTAssertEqual(store.load()?.id, "session-2")
  }

  func testRejectedImmediateWriteRetriesWithoutAnotherSaveCall() throws {
    let persistence = ToggleSessionPersistence(acceptsWrites: false)
    let store = SessionStore(persistence: persistence, saveInterval: 0.01)
    defer { store.teardown() }
    let session = Session(id: "retry-session", expireTime: Date(timeIntervalSinceNow: 1800))
    let retryAccepted = expectation(description: "Failed immediate write was retried")
    persistence.onWrite = { accepted in
      if accepted {
        retryAccepted.fulfill()
      }
    }

    store.saveImmediately(session: session)
    XCTAssertNil(persistence.read())

    persistence.acceptsWrites = true
    wait(for: [retryAccepted], timeout: 1)

    let data = try XCTUnwrap(persistence.read())
    let record = try PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)
    XCTAssertEqual(record.session.id, session.id)
  }

  func testSaveWithoutMaxLifetimeClearsPreviousMaxLifetime() {
    let cappedSession = Session(
      id: "session-1",
      expireTime: Date(timeIntervalSinceNow: 1800),
      startTime: Date(),
      maxLifetime: 4 * 60 * 60
    )
    let uncappedSession = Session(
      id: "session-2",
      expireTime: Date(timeIntervalSinceNow: 1800),
      startTime: Date()
    )

    store.saveImmediately(session: cappedSession)
    XCTAssertEqual(store.load()?.maxLifetime, 4 * 60 * 60)

    store.saveImmediately(session: uncappedSession)
    XCTAssertNil(store.load()?.maxLifetime)
  }

  func testStoreKeys() {
    let defaultPersistence = UserDefaultsSessionPersistence()
    XCTAssertEqual(defaultPersistence.recordKey, "otel-session-record")
    XCTAssertEqual(defaultPersistence.idKey, "otel-session-id")
    XCTAssertEqual(defaultPersistence.expireTimeKey, "otel-session-expire-time")
    XCTAssertEqual(defaultPersistence.startTimeKey, "otel-session-start-time")
    XCTAssertEqual(defaultPersistence.previousIdKey, "otel-session-previous-id")
    XCTAssertEqual(defaultPersistence.sessionTimeoutKey, "otel-session-timeout")
    XCTAssertEqual(defaultPersistence.maxLifetimeKey, "otel-session-max-lifetime")
  }

  func testSaveAndLoadSessionWithPreviousId() {
    let session = Session(
      id: "current-session-123",
      expireTime: Date(timeIntervalSinceNow: 1800),
      previousId: "previous-session-456",
      startTime: Date()
    )

    store.scheduleSave(session: session)

    XCTAssertEqual(store.load(), session)
  }

  func testScheduleSaveImmediatelySavesFirstSession() throws {
    let session = Session(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), startTime: Date())

    store.scheduleSave(session: session)

    let record = try decodeRecord()
    XCTAssertEqual(record.session.id, session.id)
  }

  func testTeardownClearsUserDefaults() {
    let session = Session(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), startTime: Date())
    store.saveImmediately(session: session)
    XCTAssertNotNil(persistence.read())

    store.teardown()

    XCTAssertNil(persistence.read())
    XCTAssertNil(userDefaults.object(forKey: persistence.idKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.expireTimeKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.startTimeKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.previousIdKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.sessionTimeoutKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.maxLifetimeKey))
  }

  func testTeardownInvalidatesTimer() {
    let session1 = Session(id: "test-session", expireTime: Date(timeIntervalSinceNow: 1800), startTime: Date())
    store.scheduleSave(session: session1)
    store.teardown()

    let session2 = Session(id: "test-session-2", expireTime: Date(timeIntervalSinceNow: 1800), startTime: Date())
    store.scheduleSave(session: session2)

    XCTAssertEqual(store.load()?.id, session2.id)
  }

  func testLoadSessionWithCorruptedId() {
    userDefaults.set(["invalid": "id"], forKey: persistence.idKey)
    userDefaults.set(Date(), forKey: persistence.expireTimeKey)
    userDefaults.set(Date(), forKey: persistence.startTimeKey)
    userDefaults.set(1800.0, forKey: persistence.sessionTimeoutKey)

    XCTAssertNil(store.load())
  }

  func testLoadSessionWithCorruptedExpireTime() {
    userDefaults.set("test-id", forKey: persistence.idKey)
    userDefaults.set("invalid-date", forKey: persistence.expireTimeKey)
    userDefaults.set(Date(), forKey: persistence.startTimeKey)
    userDefaults.set(1800.0, forKey: persistence.sessionTimeoutKey)

    XCTAssertNil(store.load())
  }

  func testLoadSessionWithCorruptedStartTime() {
    userDefaults.set("test-id", forKey: persistence.idKey)
    userDefaults.set(Date(), forKey: persistence.expireTimeKey)
    userDefaults.set("invalid-date", forKey: persistence.startTimeKey)
    userDefaults.set(1800.0, forKey: persistence.sessionTimeoutKey)

    XCTAssertNil(store.load())
  }

  func testLoadSessionWithCorruptedTimeout() {
    userDefaults.set("test-id", forKey: persistence.idKey)
    userDefaults.set(Date(), forKey: persistence.expireTimeKey)
    userDefaults.set(Date(), forKey: persistence.startTimeKey)
    userDefaults.set("invalid-timeout", forKey: persistence.sessionTimeoutKey)

    XCTAssertNil(store.load())
  }

  func testLoadSessionMissingTimeout() {
    userDefaults.set("test-id", forKey: persistence.idKey)
    userDefaults.set(Date(), forKey: persistence.expireTimeKey)
    userDefaults.set(Date(), forKey: persistence.startTimeKey)

    XCTAssertNil(store.load())
  }

  func testScheduleSaveWithSameSession() throws {
    let session = Session(id: "session-1", expireTime: Date(), startTime: Date())
    store.scheduleSave(session: session)
    let firstRecord = try XCTUnwrap(persistence.read())

    store.scheduleSave(session: session)

    XCTAssertEqual(persistence.read(), firstRecord)
  }

  func testScheduleSaveWithExistingTimer() throws {
    let session1 = Session(id: "session-1", expireTime: Date(), startTime: Date())
    let session2 = Session(id: "session-2", expireTime: Date(), startTime: Date())
    store.scheduleSave(session: session1)

    store.scheduleSave(session: session2)

    XCTAssertEqual(try decodeRecord().session.id, session1.id)
  }

  func testWritesOneVersionedRecord() throws {
    let session = Session(
      id: "one-record",
      expireTime: Date(timeIntervalSinceNow: 1800),
      previousId: "previous",
      startTime: Date(),
      maxLifetime: 7200
    )

    store.saveImmediately(session: session)

    let record = try decodeRecord()
    XCTAssertEqual(record.version, PersistedSessionRecord.currentVersion)
    XCTAssertEqual(record.session.value, session)
    XCTAssertNil(userDefaults.object(forKey: persistence.idKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.expireTimeKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.startTimeKey))
  }

  func testLoadMigratesLegacyKeysToVersionedRecord() throws {
    let startTime = Date(timeIntervalSinceNow: -300)
    let expireTime = Date(timeIntervalSinceNow: 1500)
    userDefaults.set("legacy-session", forKey: persistence.idKey)
    userDefaults.set("legacy-previous", forKey: persistence.previousIdKey)
    userDefaults.set(startTime, forKey: persistence.startTimeKey)
    userDefaults.set(expireTime, forKey: persistence.expireTimeKey)
    userDefaults.set(1800.0, forKey: persistence.sessionTimeoutKey)
    userDefaults.set(7200.0, forKey: persistence.maxLifetimeKey)

    let session = try XCTUnwrap(store.load())

    XCTAssertEqual(session.id, "legacy-session")
    XCTAssertEqual(session.previousId, "legacy-previous")
    XCTAssertEqual(session.startTime, startTime)
    XCTAssertEqual(session.expireTime, expireTime)
    XCTAssertEqual(session.maxLifetime, 7200)
    XCTAssertEqual(try decodeRecord().session.value, session)
    XCTAssertNil(userDefaults.object(forKey: persistence.idKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.expireTimeKey))
    XCTAssertNil(userDefaults.object(forKey: persistence.startTimeKey))
  }

  func testUnknownRecordVersionIsClearedAndPersistenceResumes() throws {
    let session = Session(id: "future-session", expireTime: Date(timeIntervalSinceNow: 1800))
    let futureRecord = PersistedSessionRecord(
      version: PersistedSessionRecord.currentVersion + 1,
      session: PersistedSession(session: session)
    )
    let data = try PropertyListEncoder().encode(futureRecord)
    persistence.write(data)

    XCTAssertNil(store.load())
    XCTAssertNil(persistence.read())
    store.saveImmediately(session: Session(id: "replacement", expireTime: Date()))
    XCTAssertEqual(try decodeRecord().session.id, "replacement")
  }

  func testCorruptedVersionedRecordFallsBackToLegacySession() throws {
    persistence.write(Data("not-a-property-list".utf8))
    let startTime = Date(timeIntervalSinceNow: -300)
    let expireTime = Date(timeIntervalSinceNow: 1500)
    userDefaults.set("legacy-session", forKey: persistence.idKey)
    userDefaults.set(startTime, forKey: persistence.startTimeKey)
    userDefaults.set(expireTime, forKey: persistence.expireTimeKey)
    userDefaults.set(1800.0, forKey: persistence.sessionTimeoutKey)

    let session = try XCTUnwrap(store.load())

    XCTAssertEqual(session.id, "legacy-session")
    XCTAssertEqual(try decodeRecord().session.value, session)
    XCTAssertNil(userDefaults.object(forKey: persistence.idKey))
  }

  func testNamespacesIsolateRecordsInOneSuite() {
    let firstPersistence = UserDefaultsSessionPersistence(userDefaults: userDefaults, namespace: "first")
    let secondPersistence = UserDefaultsSessionPersistence(userDefaults: userDefaults, namespace: "second")
    let firstStore = SessionStore(persistence: firstPersistence)
    let secondStore = SessionStore(persistence: secondPersistence)
    defer {
      firstStore.teardown()
      secondStore.teardown()
    }

    firstStore.saveImmediately(session: Session(id: "first", expireTime: Date(timeIntervalSinceNow: 1800)))
    secondStore.saveImmediately(session: Session(id: "second", expireTime: Date(timeIntervalSinceNow: 1800)))

    XCTAssertEqual(firstStore.load()?.id, "first")
    XCTAssertEqual(secondStore.load()?.id, "second")
  }

  func testInjectedPersistenceRestoresSessionInAnotherManager() throws {
    let injectedPersistence = TestSessionPersistence()
    let firstManager = try SessionManager(persistence: injectedPersistence)
    let firstSession = firstManager.getSession()

    let restoredManager = try SessionManager(persistence: injectedPersistence)

    XCTAssertEqual(restoredManager.peekSession(), firstSession)
  }

  func testUserDefaultsRejectsSharedWriterAccess() {
    XCTAssertThrowsError(
      try SessionManager(
        persistence: persistence,
        persistenceAccess: .shared
      )
    ) { error in
      XCTAssertEqual(
        error as? SessionPersistenceConfigurationError,
        .concurrentWritersUnsupported
      )
    }
  }

  func testCustomBackendAlsoRejectsSharedWriterAccess() {
    XCTAssertThrowsError(
      try SessionManager(
        persistence: TestSessionPersistence(),
        persistenceAccess: .shared
      )
    ) { error in
      XCTAssertEqual(
        error as? SessionPersistenceConfigurationError,
        .concurrentWritersUnsupported
      )
    }
  }

  func testSharedStoreInterleavingKeepsOneCompleteRecord() throws {
    let sharedPersistence = TestSessionPersistence()
    let firstStore = SessionStore(persistence: sharedPersistence)
    let secondStore = SessionStore(persistence: sharedPersistence)
    var sessions: [Session] = []
    for index in 0 ..< 50 {
      let timestamp = TimeInterval(index)
      sessions.append(Session(
        id: "session-\(index)",
        expireTime: Date(timeIntervalSince1970: timestamp),
        previousId: "previous-\(index)",
        startTime: Date(timeIntervalSince1970: timestamp),
        sessionTimeout: TimeInterval(index + 1),
        maxLifetime: TimeInterval(index + 2)
      ))
    }
    let immutableSessions = sessions

    DispatchQueue.concurrentPerform(iterations: immutableSessions.count) { index in
      let targetStore = index.isMultiple(of: 2) ? firstStore : secondStore
      targetStore.saveImmediately(session: immutableSessions[index])
    }

    let data = try XCTUnwrap(sharedPersistence.read())
    let record = try PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)
    let matchingSession = try XCTUnwrap(immutableSessions.first { $0.id == record.session.id })
    XCTAssertEqual(record.session.value, matchingSession)
  }

  private func decodeRecord() throws -> PersistedSessionRecord {
    let data = try XCTUnwrap(persistence.read())
    return try PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)
  }
}

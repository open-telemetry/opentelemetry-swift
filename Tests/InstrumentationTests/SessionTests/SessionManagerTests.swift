import XCTest
import OpenTelemetryApi
@testable import Sessions
@testable import OpenTelemetrySdk

final class SessionManagerTests: XCTestCase {
  var sessionManager: SessionManager!
  private var previousQueuedEvents: [SessionEvent] = []
  private var previousInstrumentationState = false

  override func setUp() {
    super.setUp()
    previousQueuedEvents = SessionEventInstrumentation.queue
    previousInstrumentationState = SessionEventInstrumentation.isApplied
    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = false
    SessionStore.teardown()
    sessionManager = SessionManager()
  }

  override func tearDown() {
    SessionStore.teardown()
    SessionEventInstrumentation.queue = previousQueuedEvents
    SessionEventInstrumentation.isApplied = previousInstrumentationState
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
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

  func testGetSessionRecordsActivity() {
    let t1 = sessionManager.getSession().expireTime
    Thread.sleep(forTimeInterval: 0.1)
    let t2 = sessionManager.getSession().expireTime
    XCTAssertGreaterThan(t2, t1)
  }

  func testResetWithoutExistingSessionCreatesInitialSession() {
    let session = sessionManager.resetSession()

    XCTAssertNil(session.previousId)
    XCTAssertEqual(SessionStore.load()?.id, session.id)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].eventType, .start)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.id, session.id)
  }

  func testGetSessionExtendsSessionAndPreservesStartTime() {
    let originalSession = sessionManager.getSession()
    Thread.sleep(forTimeInterval: 0.1)
    let extendedSession = sessionManager.getSession()

    XCTAssertEqual(originalSession.id, extendedSession.id)
    XCTAssertGreaterThan(extendedSession.expireTime, originalSession.expireTime)
    XCTAssertEqual(originalSession.startTime, extendedSession.startTime)
  }

  func testGetSessionAfterExpiryStartsLinkedSession() {
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 0))
    let expiredSession = sessionManager.getSession()

    let activeSession = sessionManager.getSession()

    XCTAssertNotEqual(activeSession.id, expiredSession.id)
    XCTAssertEqual(activeSession.previousId, expiredSession.id)
  }

  func testResetSessionEndsCurrentSessionAndPersistsLinkedReplacement() {
    let originalSession = sessionManager.getSession()
    SessionEventInstrumentation.queue = []

    let replacementSession = sessionManager.resetSession()

    XCTAssertNotEqual(replacementSession.id, originalSession.id)
    XCTAssertEqual(replacementSession.previousId, originalSession.id)
    XCTAssertEqual(SessionStore.load()?.id, replacementSession.id)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    guard SessionEventInstrumentation.queue.count == 2 else { return }
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.id, originalSession.id)
    XCTAssertEqual(
      SessionEventInstrumentation.queue[0].session.endTime,
      replacementSession.startTime
    )
    if case .end = SessionEventInstrumentation.queue[0].eventType {} else {
      XCTFail("Expected one session.end event")
    }
    XCTAssertEqual(SessionEventInstrumentation.queue[1].session.id, replacementSession.id)
    if case .start = SessionEventInstrumentation.queue[1].eventType {} else {
      XCTFail("Expected one session.start event")
    }
  }

  func testConcurrentAccessAfterExpiryStartsOneReplacement() throws {
    let expiredSession = Session(
      id: "expired-session",
      expireTime: Date(timeIntervalSinceNow: -60),
      startTime: Date(timeIntervalSinceNow: -120),
      sessionTimeout: 60
    )
    SessionStore.saveImmediately(session: expiredSession)
    sessionManager = SessionManager()
    let manager = try XCTUnwrap(sessionManager)

    let resultLock = NSLock()
    nonisolated(unsafe) var sessionIds: [String] = []
    DispatchQueue.concurrentPerform(iterations: 50) { _ in
      let sessionId = manager.getSession().id
      resultLock.withLock { sessionIds.append(sessionId) }
    }

    XCTAssertEqual(Set(sessionIds).count, 1)
    XCTAssertEqual(sessionManager.peekSession()?.previousId, expiredSession.id)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
  }

  func testConcurrentResetsPersistAndPublishOneLinkedChain() throws {
    let originalSession = sessionManager.getSession()
    let manager = try XCTUnwrap(sessionManager)
    SessionEventInstrumentation.queue = []
    let transitionsPublished = expectation(description: "Concurrent transitions published")
    transitionsPublished.expectedFulfillmentCount = 10
    let observer = NotificationCenter.default.addObserver(
      forName: SessionEventNotification,
      object: nil,
      queue: nil
    ) { _ in
      transitionsPublished.fulfill()
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    DispatchQueue.concurrentPerform(iterations: 10) { _ in
      manager.resetSession()
    }
    wait(for: [transitionsPublished], timeout: 2)

    let events = SessionEventInstrumentation.queue
    XCTAssertEqual(events.count, 20)
    guard events.count == 20 else { return }
    var expectedPreviousId = originalSession.id
    for eventIndex in stride(from: 0, to: events.count, by: 2) {
      let endEvent = events[eventIndex]
      let startEvent = events[eventIndex + 1]
      if case .end = endEvent.eventType {} else {
        XCTFail("Expected session.end before each replacement")
      }
      if case .start = startEvent.eventType {} else {
        XCTFail("Expected session.start after each ended session")
      }
      XCTAssertEqual(endEvent.session.id, expectedPreviousId)
      XCTAssertEqual(startEvent.session.previousId, endEvent.session.id)
      expectedPreviousId = startEvent.session.id
    }
    XCTAssertEqual(SessionStore.load()?.id, expectedPreviousId)
    XCTAssertEqual(manager.peekSession()?.id, expectedPreviousId)
  }

  func testResetSessionKeepsAnExpiredSessionEndTime() {
    sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 0))
    let expiredSession = sessionManager.getSession()
    let expiredEndTime = expiredSession.endTime
    SessionEventInstrumentation.queue = []

    let replacementSession = sessionManager.resetSession()

    XCTAssertEqual(replacementSession.previousId, expiredSession.id)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.id, expiredSession.id)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.endTime, expiredEndTime)
  }

  func testResetSessionUsesPersistedPreviousSessionBeforeFirstAccess() {
    let sessionTimeout: TimeInterval = 60 * 60
    let lastActivity = Date(timeIntervalSinceNow: -60)
    let persistedSession = Session(
      id: "persisted-session",
      expireTime: lastActivity.addingTimeInterval(sessionTimeout),
      startTime: Date(timeIntervalSinceNow: -120),
      sessionTimeout: sessionTimeout
    )
    SessionStore.saveImmediately(session: persistedSession)
    sessionManager = SessionManager(configuration: SessionConfig(
      sessionTimeout: sessionTimeout,
      restorePersistedSession: false
    ))

    let replacementSession = sessionManager.resetSession()

    XCTAssertEqual(replacementSession.previousId, persistedSession.id)
    XCTAssertEqual(SessionStore.load()?.id, replacementSession.id)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.id, persistedSession.id)
    XCTAssertEqual(
      SessionEventInstrumentation.queue[0].session.endTime?.timeIntervalSince1970 ?? 0,
      lastActivity.timeIntervalSince1970,
      accuracy: 1.0
    )
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
    let savedSession = SessionStore.load()

    XCTAssertEqual(session, savedSession)
    XCTAssertNotNil(UserDefaults.standard.data(forKey: SessionStore.recordKey))
    XCTAssertNil(UserDefaults.standard.object(forKey: SessionStore.idKey))
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

  func testAppliedSessionEventPipelineDoesNotReenterSessionAccess() {
    let manager = CountingSessionManager()
    let exporter = InMemoryLogRecordExporter()
    let processor = SessionLogRecordProcessor(
      nextProcessor: SimpleLogRecordProcessor(logRecordExporter: exporter),
      sessionManager: manager
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    SessionEventInstrumentation.install()

    let session = manager.getSession()

    let records = exporter.getFinishedLogRecords()
    XCTAssertEqual(manager.sessionAccessCount, 1)
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records[0].eventName, SessionConstants.sessionStartEvent)
    XCTAssertEqual(
      records[0].attributes[SemanticConventions.Session.id.rawValue],
      AttributeValue.string(session.id)
    )
  }

  func testSlowSessionExporterDoesNotBlockConcurrentAccessOrReset() {
    let manager = SessionManager()
    let blockingProcessor = BlockingLogRecordProcessor()
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [blockingProcessor])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    SessionEventInstrumentation.install()

    let transitionFinished = expectation(description: "Session transition finished")
    DispatchQueue.global().async {
      manager.getSession()
      transitionFinished.fulfill()
    }
    XCTAssertEqual(blockingProcessor.didStart.wait(timeout: .now() + 1), .success)
    let secondAccessFinished = expectation(description: "Second access remained available")
    DispatchQueue.global().async {
      manager.getSession()
      secondAccessFinished.fulfill()
    }
    wait(for: [secondAccessFinished], timeout: 0.5)

    let thirdAccessFinished = expectation(description: "Third access remained available")
    DispatchQueue.global().async {
      manager.getSession()
      thirdAccessFinished.fulfill()
    }
    wait(for: [thirdAccessFinished], timeout: 0.5)

    let resetFinished = expectation(description: "Explicit reset remained available")
    let resetLock = NSLock()
    nonisolated(unsafe) var resetSession: Session?
    DispatchQueue.global().async {
      let replacement = manager.resetSession()
      resetLock.withLock { resetSession = replacement }
      resetFinished.fulfill()
    }
    wait(for: [resetFinished], timeout: 0.5)
    let replacement = resetLock.withLock { resetSession }
    XCTAssertEqual(SessionStore.load()?.id, replacement?.id)
    XCTAssertEqual(SessionStore.load()?.id, manager.peekSession()?.id)

    blockingProcessor.allowCompletion.signal()
    wait(for: [transitionFinished], timeout: 1)
    XCTAssertEqual(SessionStore.load()?.id, manager.peekSession()?.id)
  }

  func testInjectedPersistenceContainsResetBeforeReturnWhileEventsAreBlocked() throws {
    let persistence = TestSessionPersistence()
    let manager = try SessionManager(persistence: persistence)
    let blockingProcessor = BlockingLogRecordProcessor()
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [blockingProcessor])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    SessionEventInstrumentation.install()

    let initialTransitionFinished = expectation(description: "Initial transition finished")
    DispatchQueue.global().async {
      manager.getSession()
      initialTransitionFinished.fulfill()
    }
    XCTAssertEqual(blockingProcessor.didStart.wait(timeout: .now() + 1), .success)

    let replacement = manager.resetSession()
    let persistedDataBeforeUnblock = persistence.read()

    blockingProcessor.allowCompletion.signal()
    wait(for: [initialTransitionFinished], timeout: 1)
    let data = try XCTUnwrap(persistedDataBeforeUnblock)
    let record = try PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)
    XCTAssertEqual(record.session.id, replacement.id)
    XCTAssertEqual(manager.peekSession()?.id, replacement.id)
  }

  func testInjectedPersistenceCanInspectCurrentSessionDuringWrite() throws {
    let persistence = InspectingSessionPersistence()
    let manager = try SessionManager(persistence: persistence)
    persistence.onWrite = { _ = manager.peekSession() }
    let completed = expectation(description: "Persistence callback completed")

    DispatchQueue.global().async {
      _ = manager.resetSession()
      completed.fulfill()
    }

    wait(for: [completed], timeout: 1)
    XCTAssertEqual(persistence.writeCount, 1)
    XCTAssertEqual(manager.peekSession()?.id, persistence.persistedSessionId)
  }

  func testTransitionDoesNotWaitForCrossThreadDrainerCallback() {
    let manager = SessionManager()
    let callbackQueue = DispatchQueue(label: "io.opentelemetry.sessions.callback")
    let eventsPublished = expectation(description: "Initial and reset events published")
    eventsPublished.expectedFulfillmentCount = 3
    let processor = QueueHoppingLogRecordProcessor(
      callbackQueue: callbackQueue,
      eventExpectation: eventsPublished
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    SessionEventInstrumentation.install()

    let resetFinished = expectation(description: "Reset returned from callback queue")
    callbackQueue.async {
      guard processor.didStart.wait(timeout: .now() + 1) == .success else { return }
      manager.resetSession()
      resetFinished.fulfill()
    }

    let transitionFinished = expectation(description: "Initial transition finished")
    DispatchQueue.global().async {
      manager.getSession()
      transitionFinished.fulfill()
    }

    wait(for: [resetFinished, transitionFinished, eventsPublished], timeout: 2)
    XCTAssertEqual(processor.hopCount, 1)
    XCTAssertEqual(SessionStore.load()?.id, manager.peekSession()?.id)
  }

  func testCallerDoesNotDrainTransitionsQueuedDuringCallback() {
    let manager = SessionManager()
    let callerQueue = DispatchQueue(label: "io.opentelemetry.sessions.caller")
    let eventsPublished = expectation(description: "Contended transitions published")
    eventsPublished.expectedFulfillmentCount = 11
    let processor = ContendedTransitionLogRecordProcessor(
      sessionManager: manager,
      callerQueue: callerQueue,
      eventExpectation: eventsPublished,
      resetCount: 5
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    SessionEventInstrumentation.install()

    let callerFinished = expectation(description: "Initial caller returned")
    callerQueue.async {
      manager.getSession()
      callerFinished.fulfill()
    }

    wait(for: [callerFinished, eventsPublished], timeout: 2)
    XCTAssertTrue(processor.producerFinishedSuccessfully)
    XCTAssertEqual(processor.callerQueueEventCount, 1)
    XCTAssertEqual(SessionStore.load()?.id, manager.peekSession()?.id)
  }

  func testReentrantResetDrainsNestedTransition() {
    let manager = SessionManager()
    let eventsPublished = expectation(description: "Nested transition events published")
    eventsPublished.expectedFulfillmentCount = 3
    let processor = ReentrantResetLogRecordProcessor(
      sessionManager: manager,
      eventExpectation: eventsPublished
    )
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    SessionEventInstrumentation.install()

    let transitionFinished = expectation(description: "Nested session transition finished")
    DispatchQueue.global().async {
      manager.getSession()
      transitionFinished.fulfill()
    }
    wait(for: [transitionFinished, eventsPublished], timeout: 1)

    XCTAssertEqual(processor.eventNames, [
      SessionConstants.sessionStartEvent,
      SessionConstants.sessionEndEvent,
      SessionConstants.sessionStartEvent
    ])
    XCTAssertEqual(SessionStore.load()?.id, manager.peekSession()?.id)
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

private final class CountingSessionManager: SessionManager, @unchecked Sendable {
  private let countLock = NSLock()
  private var _sessionAccessCount = 0

  var sessionAccessCount: Int {
    return countLock.withLock { _sessionAccessCount }
  }

  override func getSession() -> Session {
    countLock.withLock { _sessionAccessCount += 1 }
    return super.getSession()
  }
}

private final class BlockingLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
  let didStart = DispatchSemaphore(value: 0)
  let allowCompletion = DispatchSemaphore(value: 0)
  private let lock = NSLock()
  private var shouldBlock = true

  func onEmit(logRecord: ReadableLogRecord) {
    let block = lock.withLock {
      defer { shouldBlock = false }
      return shouldBlock
    }
    guard block else { return }

    didStart.signal()
    _ = allowCompletion.wait(timeout: .now() + 5)
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}

private final class ReentrantResetLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
  private let sessionManager: SessionManager
  private let eventExpectation: XCTestExpectation
  private let lock = NSLock()
  private var didReset = false
  private var _eventNames: [String] = []

  init(sessionManager: SessionManager, eventExpectation: XCTestExpectation) {
    self.sessionManager = sessionManager
    self.eventExpectation = eventExpectation
  }

  var eventNames: [String] {
    return lock.withLock { _eventNames }
  }

  func onEmit(logRecord: ReadableLogRecord) {
    eventExpectation.fulfill()
    let shouldReset = lock.withLock {
      if let eventName = logRecord.eventName {
        _eventNames.append(eventName)
      }
      guard !didReset, logRecord.eventName == SessionConstants.sessionStartEvent else {
        return false
      }
      didReset = true
      return true
    }
    if shouldReset {
      sessionManager.resetSession()
    }
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}

private final class QueueHoppingLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
  let didStart = DispatchSemaphore(value: 0)
  private let callbackQueue: DispatchQueue
  private let eventExpectation: XCTestExpectation
  private let lock = NSLock()
  private var shouldHop = true
  private var _hopCount = 0

  init(callbackQueue: DispatchQueue, eventExpectation: XCTestExpectation) {
    self.callbackQueue = callbackQueue
    self.eventExpectation = eventExpectation
  }

  var hopCount: Int {
    return lock.withLock { _hopCount }
  }

  func onEmit(logRecord: ReadableLogRecord) {
    eventExpectation.fulfill()
    let hop = lock.withLock {
      guard shouldHop else { return false }
      shouldHop = false
      return true
    }
    guard hop else { return }

    didStart.signal()
    callbackQueue.sync {
      lock.withLock { _hopCount += 1 }
    }
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}

private final class ContendedTransitionLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
  private let sessionManager: SessionManager
  private let callerQueueKey = DispatchSpecificKey<Void>()
  private let eventExpectation: XCTestExpectation
  private let resetCount: Int
  private let producerFinished = DispatchSemaphore(value: 0)
  private let lock = NSLock()
  private var startedProducer = false
  private var _producerFinishedSuccessfully = false
  private var _callerQueueEventCount = 0

  init(sessionManager: SessionManager,
       callerQueue: DispatchQueue,
       eventExpectation: XCTestExpectation,
       resetCount: Int) {
    self.sessionManager = sessionManager
    self.eventExpectation = eventExpectation
    self.resetCount = resetCount
    callerQueue.setSpecific(key: callerQueueKey, value: ())
  }

  var producerFinishedSuccessfully: Bool {
    return lock.withLock { _producerFinishedSuccessfully }
  }

  var callerQueueEventCount: Int {
    return lock.withLock { _callerQueueEventCount }
  }

  func onEmit(logRecord: ReadableLogRecord) {
    eventExpectation.fulfill()
    let shouldProduce = lock.withLock {
      if DispatchQueue.getSpecific(key: callerQueueKey) != nil {
        _callerQueueEventCount += 1
      }
      guard !startedProducer else { return false }
      startedProducer = true
      return true
    }
    guard shouldProduce else { return }

    DispatchQueue.global().async { [self] in
      for _ in 0 ..< resetCount {
        sessionManager.resetSession()
      }
      producerFinished.signal()
    }
    let finished = producerFinished.wait(timeout: .now() + 1) == .success
    lock.withLock { _producerFinishedSuccessfully = finished }
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}

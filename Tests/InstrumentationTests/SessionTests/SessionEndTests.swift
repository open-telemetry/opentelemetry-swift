/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
import OpenTelemetryApi
@testable import Sessions
@testable import OpenTelemetrySdk

final class SessionEndTests: XCTestCase {
  private var previousQueuedEvents: [SessionEvent] = []
  private var previousInstrumentationState = false

  override func setUp() {
    super.setUp()
    previousQueuedEvents = SessionEventInstrumentation.queue
    previousInstrumentationState = SessionEventInstrumentation.isApplied
    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = false
    SessionStore.teardown()
  }

  override func tearDown() {
    SessionStore.teardown()
    SessionEventInstrumentation.queue = previousQueuedEvents
    SessionEventInstrumentation.isApplied = previousInstrumentationState
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
    super.tearDown()
  }

  func testEndBeforeFirstAccessDoesNotCreateSessionOrEvents() {
    let manager = SessionManager()
    manager.endSession()
    manager.endSession()

    XCTAssertNil(manager.peekSession())
    XCTAssertNil(SessionStore.load())
    XCTAssertTrue(SessionEventInstrumentation.queue.isEmpty)
  }

  func testEndClearsStateAndEmitsOnlyEndWithOriginalContext() throws {
    let manager = SessionManager()
    let first = manager.getSession()
    let current = manager.resetSession()
    SessionEventInstrumentation.queue = []
    let observer = NotificationCenter.default.addObserver(
      forName: SessionEventNotification, object: nil, queue: nil
    ) { _ in
      XCTFail("Ending a session must not post a session-start notification")
    }
    defer { NotificationCenter.default.removeObserver(observer) }
    let before = Date()

    manager.endSession()
    manager.endSession()

    let after = Date()
    XCTAssertNil(manager.peekSession())
    XCTAssertNil(SessionStore.load())
    let events = SessionEventInstrumentation.queue
    XCTAssertEqual(events.count, 1)
    let end = try XCTUnwrap(events.first)
    XCTAssertEqual(end.eventType, .end)
    XCTAssertEqual(end.session.id, current.id)
    XCTAssertEqual(end.session.previousId, first.id)
    XCTAssertEqual(end.session.startTime, current.startTime)
    let endTime = try XCTUnwrap(end.session.endTime)
    XCTAssertGreaterThanOrEqual(endTime, before)
    XCTAssertLessThanOrEqual(endTime, after)
  }

  func testGetAfterEndStartsUnlinkedSessionWithoutDuplicateEnd() {
    let manager = SessionManager()
    let original = manager.getSession()
    manager.endSession()

    let next = manager.getSession()

    XCTAssertNotEqual(next.id, original.id)
    XCTAssertNil(next.previousId)
    XCTAssertEqual(SessionStore.load(), next)
    XCTAssertEqual(SessionEventInstrumentation.queue.map(\.eventType), [.start, .end, .start])
  }

  func testResetAfterEndStartsUnlinkedSession() {
    let manager = SessionManager()
    let original = manager.getSession()
    manager.endSession()

    let next = manager.resetSession()

    XCTAssertNotEqual(next.id, original.id)
    XCTAssertNil(next.previousId)
    XCTAssertEqual(SessionEventInstrumentation.queue.map(\.eventType), [.start, .end, .start])
  }

  func testEndKeepsInactivityAndMaxLifetimeEndTimes() throws {
    let now = Date()
    for maxLifetime: TimeInterval? in [nil, 15] {
      let saved = Session(
        id: UUID().uuidString,
        expireTime: now.addingTimeInterval(-30),
        startTime: now.addingTimeInterval(-120),
        sessionTimeout: 60,
        maxLifetime: maxLifetime
      )
      SessionStore.saveImmediately(session: saved)
      let manager = SessionManager()
      SessionEventInstrumentation.queue = []

      manager.endSession()

      let end = try XCTUnwrap(SessionEventInstrumentation.queue.first)
      XCTAssertEqual(end.eventType, .end)
      XCTAssertEqual(end.session.endTime, saved.endTime)
      XCTAssertNil(SessionStore.load())
    }
  }

  func testEndClearsRestoredAndPendingPreviousSessions() throws {
    for restore in [true, false] {
      let lastActivity = Date(timeIntervalSinceNow: -60)
      let saved = Session(
        id: UUID().uuidString,
        expireTime: lastActivity.addingTimeInterval(1800),
        startTime: lastActivity.addingTimeInterval(-60),
        sessionTimeout: 1800
      )
      SessionStore.saveImmediately(session: saved)
      let manager = SessionManager(configuration: SessionConfig(restorePersistedSession: restore))
      SessionEventInstrumentation.queue = []

      manager.endSession()
      manager.endSession()

      XCTAssertNil(manager.peekSession())
      XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
      let end = try XCTUnwrap(SessionEventInstrumentation.queue.first)
      XCTAssertEqual(end.eventType, .end)
      XCTAssertEqual(end.session.id, saved.id)
      if !restore {
        XCTAssertEqual(end.session.endTime, lastActivity)
      }
      XCTAssertNil(manager.getSession().previousId)
      manager.endSession()
    }
  }

  func testEndedSessionIsNotRestoredOrLinkedByNewManager() {
    for restore in [true, false] {
      let manager = SessionManager()
      let original = manager.getSession()
      manager.endSession()
      let relaunched = SessionManager(configuration: SessionConfig(restorePersistedSession: restore))

      XCTAssertNil(relaunched.peekSession())
      let next = relaunched.getSession()
      XCTAssertNotEqual(next.id, original.id)
      XCTAssertNil(next.previousId)
      relaunched.endSession()
    }
  }

  func testPendingSaveCannotRestoreEndedSessionAfterTimerDeadline() {
    let manager = SessionManager()
    manager.getSession()
    manager.getSession()
    manager.getSession()
    manager.endSession()

    // Exercise the real 30-second save timer without load(), which clears pending saves.
    let timerDeadline = expectation(description: "Passed the old save deadline")
    DispatchQueue.main.asyncAfter(deadline: .now() + 31) { timerDeadline.fulfill() }
    wait(for: [timerDeadline], timeout: 35)

    XCTAssertNil(manager.peekSession())
    for key in [SessionStore.idKey, SessionStore.previousIdKey, SessionStore.startTimeKey,
                SessionStore.expireTimeKey, SessionStore.sessionTimeoutKey, SessionStore.maxLifetimeKey] {
      XCTAssertNil(UserDefaults.standard.object(forKey: key), key)
    }
    let next = manager.getSession()
    let refreshed = manager.getSession()
    XCTAssertEqual(SessionStore.load(), refreshed)
    XCTAssertEqual(next.id, refreshed.id)
    XCTAssertNil(next.previousId)
  }

  func testLifecycleLogDoesNotStartReplacementButLaterApplicationLogDoes() throws {
    let manager = SessionManager()
    let recorder = EndSessionLogRecordProcessor()
    let provider = install(recorder, manager: manager)
    let original = manager.getSession()

    manager.endSession()

    XCTAssertNil(manager.peekSession())
    XCTAssertEqual(recorder.records.map(\.eventName), [SessionConstants.sessionStartEvent, SessionConstants.sessionEndEvent])
    XCTAssertEqual(recorder.records.last?.attributes[SemanticConventions.Session.id.rawValue], .string(original.id))
    provider.get(instrumentationScopeName: "session-end-test").logRecordBuilder().setBody(.string("after end")).emit()

    let next = try XCTUnwrap(manager.peekSession())
    XCTAssertNotEqual(next.id, original.id)
    XCTAssertNil(next.previousId)
    let records = recorder.records
    XCTAssertEqual(records.count, 4)
    guard records.count == 4 else { return }
    XCTAssertEqual(records[2].eventName, SessionConstants.sessionStartEvent)
    XCTAssertEqual(records[3].attributes[SemanticConventions.Session.id.rawValue], .string(next.id))
    XCTAssertNil(records[3].attributes[SemanticConventions.Session.previousId.rawValue])
  }

  func testLaterSpanStartsFreshSessionAndExistingSpanKeepsItsSession() throws {
    let manager = SessionManager()
    let provider = TracerProviderBuilder().add(spanProcessor: SessionSpanProcessor(sessionManager: manager)).build()
    let tracer = provider.get(instrumentationName: "session-end-test")
    let before = tracer.spanBuilder(spanName: "before end").startSpan()
    let original = try XCTUnwrap(manager.peekSession())

    manager.endSession()
    before.end()
    XCTAssertNil(manager.peekSession())
    let after = tracer.spanBuilder(spanName: "after end").startSpan()
    after.end()

    let next = try XCTUnwrap(manager.peekSession())
    XCTAssertNotEqual(next.id, original.id)
    XCTAssertNil(next.previousId)
    XCTAssertEqual((before as? ReadableSpan)?.getAttributes()[SemanticConventions.Session.id.rawValue], .string(original.id))
    XCTAssertEqual((after as? ReadableSpan)?.getAttributes()[SemanticConventions.Session.id.rawValue], .string(next.id))
    XCTAssertNil((after as? ReadableSpan)?.getAttributes()[SemanticConventions.Session.previousId.rawValue])
    XCTAssertEqual(SessionEventInstrumentation.queue.map(\.eventType), [.start, .end, .start])
  }

  func testConcurrentEndEmitsOnce() {
    let manager = SessionManager()
    let recorder = EndSessionLogRecordProcessor()
    install(recorder, manager: manager)
    let original = manager.getSession()

    DispatchQueue.concurrentPerform(iterations: 50) { _ in manager.endSession() }

    XCTAssertNil(manager.peekSession())
    XCTAssertNil(SessionStore.load())
    XCTAssertEqual(recorder.records.map(\.eventName), [SessionConstants.sessionStartEvent, SessionConstants.sessionEndEvent])
    XCTAssertEqual(recorder.records.last?.attributes[SemanticConventions.Session.id.rawValue], .string(original.id))
  }

  func testEndFromStartCallbackDrainsOnceWithoutDeadlock() {
    let manager = SessionManager()
    let ended = expectation(description: "Reentrant end published")
    let recorder = EndSessionLogRecordProcessor { record in
      if record.eventName == SessionConstants.sessionStartEvent {
        manager.endSession()
      } else {
        manager.endSession()
        XCTAssertNil(manager.peekSession())
        XCTAssertNil(SessionStore.load())
        ended.fulfill()
      }
    }
    install(recorder, manager: manager)
    let returned = expectation(description: "Initial call returned")
    DispatchQueue.global().async {
      manager.getSession()
      returned.fulfill()
    }
    wait(for: [returned, ended], timeout: 3)

    XCTAssertEqual(recorder.records.map(\.eventName), [SessionConstants.sessionStartEvent, SessionConstants.sessionEndEvent])
    XCTAssertNil(manager.peekSession())
  }

  func testConcurrentAccessResetAndEndKeepBalancedOrderedEvents() throws {
    let manager = SessionManager()
    let recorder = EndSessionLogRecordProcessor()
    install(recorder, manager: manager)

    DispatchQueue.concurrentPerform(iterations: 100) { index in
      switch index % 3 {
      case 0: manager.getSession()
      case 1: manager.resetSession()
      default: manager.endSession()
      }
    }
    let finalSession = manager.resetSession()
    manager.endSession()
    let drained = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      let last = recorder.records.last
      return last?.eventName == SessionConstants.sessionEndEvent &&
        last?.attributes[SemanticConventions.Session.id.rawValue] == .string(finalSession.id)
    }, object: nil)
    wait(for: [drained], timeout: 3)

    var activeId: AttributeValue?
    var startedIds = Set<String>()
    for record in recorder.records {
      let id = try XCTUnwrap(record.attributes[SemanticConventions.Session.id.rawValue])
      if record.eventName == SessionConstants.sessionStartEvent {
        XCTAssertNil(activeId)
        XCTAssertTrue(startedIds.insert(id.description).inserted)
        activeId = id
      } else {
        XCTAssertEqual(record.eventName, SessionConstants.sessionEndEvent)
        XCTAssertEqual(id, activeId)
        activeId = nil
      }
    }
    XCTAssertNil(activeId)
    XCTAssertNil(manager.peekSession())
    XCTAssertNil(SessionStore.load())
  }

  func testGetFromEndCallbackStartsUnlinkedSessionInOrder() throws {
    let manager = SessionManager()
    let restarted = expectation(description: "Callback's new session published")
    let recorder = EndSessionLogRecordProcessor { record in
      if record.eventName == SessionConstants.sessionEndEvent {
        XCTAssertNil(manager.peekSession())
        XCTAssertNil(SessionStore.load())
        XCTAssertNil(manager.getSession().previousId)
      }
    }
    install(recorder, manager: manager)
    let original = manager.getSession()
    let observer = NotificationCenter.default.addObserver(
      forName: SessionEventNotification, object: nil, queue: nil
    ) { _ in restarted.fulfill() }
    defer { NotificationCenter.default.removeObserver(observer) }

    manager.endSession()
    wait(for: [restarted], timeout: 3)

    XCTAssertNotEqual(try XCTUnwrap(manager.peekSession()).id, original.id)
    XCTAssertEqual(recorder.records.map(\.eventName), [SessionConstants.sessionStartEvent, SessionConstants.sessionEndEvent, SessionConstants.sessionStartEvent])
  }

  func testSlowExporterDoesNotBlockEndAndQueuedTransitionsStayOrdered() {
    let manager = SessionManager()
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let finalEnd = expectation(description: "Queued replacement ended")
    let recorder = EndSessionLogRecordProcessor { record in
      if record.eventName == SessionConstants.sessionStartEvent,
         record.attributes[SemanticConventions.Session.previousId.rawValue] == nil {
        entered.signal()
        XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
      }
      if record.eventName == SessionConstants.sessionEndEvent,
         record.attributes[SemanticConventions.Session.previousId.rawValue] != nil {
        finalEnd.fulfill()
      }
    }
    install(recorder, manager: manager)
    let returned = expectation(description: "Initial call returned")
    DispatchQueue.global().async {
      manager.getSession()
      returned.fulfill()
    }
    XCTAssertEqual(entered.wait(timeout: .now() + 2), .success)
    let ended = expectation(description: "End returned while exporter blocked")
    DispatchQueue.global().async {
      manager.resetSession()
      manager.endSession()
      ended.fulfill()
    }
    wait(for: [ended], timeout: 2)
    XCTAssertNil(manager.peekSession())
    XCTAssertNil(SessionStore.load())
    release.signal()
    wait(for: [returned, finalEnd], timeout: 3)

    let records = recorder.records
    XCTAssertEqual(records.map(\.eventName), [SessionConstants.sessionStartEvent, SessionConstants.sessionEndEvent,
                                              SessionConstants.sessionStartEvent, SessionConstants.sessionEndEvent])
    guard records.count == 4 else { return }
    XCTAssertEqual(records[0].attributes[SemanticConventions.Session.id.rawValue], records[1].attributes[SemanticConventions.Session.id.rawValue])
    XCTAssertEqual(records[2].attributes[SemanticConventions.Session.id.rawValue], records[3].attributes[SemanticConventions.Session.id.rawValue])
  }

  @discardableResult
  private func install(_ recorder: EndSessionLogRecordProcessor, manager: SessionManager) -> LoggerProviderSdk {
    let provider = LoggerProviderBuilder().with(processors: [
      SessionLogRecordProcessor(nextProcessor: recorder, sessionManager: manager)
    ]).build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: provider)
    SessionEventInstrumentation.install()
    return provider
  }
}

private final class EndSessionLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
  private let lock = NSLock()
  private var receivedRecords: [ReadableLogRecord] = []
  private let callback: @Sendable (ReadableLogRecord) -> Void

  init(callback: @escaping @Sendable (ReadableLogRecord) -> Void = { _ in }) {
    self.callback = callback
  }

  var records: [ReadableLogRecord] {
    return lock.withLock { receivedRecords }
  }

  func onEmit(logRecord: ReadableLogRecord) {
    lock.withLock { receivedRecords.append(logRecord) }
    callback(logRecord)
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}

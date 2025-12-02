import XCTest
@testable import Sessions
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk

final class SessionEventInstrumentationTests: XCTestCase {
  let sessionId1 = "test-session-id-1"
  let sessionId2 = "test-session-id-2"
  let sessionIdExpired = "test-session-id-expired"

  var startTime1: Date!
  var startTime2: Date!
  var logExporter: InMemoryLogRecordExporter!

  lazy var session1 = Session(
    id: sessionId1,
    expireTime: Date().addingTimeInterval(3600),
    previousId: nil,
    startTime: startTime1
  )

  lazy var session2 = Session(
    id: sessionId2,
    expireTime: Date().addingTimeInterval(3600),
    previousId: sessionId1,
    startTime: startTime2
  )

  lazy var sessionExpired = Session(
    id: sessionIdExpired,
    expireTime: Date().addingTimeInterval(-3600),
    startTime: Date().addingTimeInterval(-7200)
  )

  override func setUp() {
    super.setUp()

    startTime1 = Date()
    startTime2 = Date().addingTimeInterval(60)

    // Reset static state FIRST
    SessionStore.teardown()
    SessionEventInstrumentation.queue.removeAll()
    SessionEventInstrumentation.isApplied = false

    // Then setup LoggerProvider
    logExporter = InMemoryLogRecordExporter()
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
  }

  override func tearDown() {
    super.tearDown()

    SessionStore.teardown()
    OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
  }

  func testQueueInitiallyEmpty() {
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
    XCTAssertFalse(SessionEventInstrumentation.isApplied)
  }

  func testHandleNewSessionAddsToQueue() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].session.id, sessionId1)
  }

  func testInstrumentationEmptiesQueue() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    XCTAssertFalse(SessionEventInstrumentation.isApplied)

    SessionEventInstrumentation.install()

    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testQueueDoesNotFillAfterApplied() {
    SessionEventInstrumentation.install()

    SessionEventInstrumentation.addSession(session: session2, eventType: .start)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testMultipleInstallationDoesNotProcessQueueTwice() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)

    SessionEventInstrumentation.install()
    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)

    // Second installation should not process queue again
    SessionEventInstrumentation.install()
    XCTAssertTrue(SessionEventInstrumentation.isApplied)
  }

  func testMultipleInstallationIsSafe() {
    SessionEventInstrumentation.install()
    SessionEventInstrumentation.install()

    SessionEventInstrumentation.addSession(session: session1, eventType: .start)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    guard logRecords.count > 0 else {
      XCTFail("No log records found")
      return
    }
    XCTAssertEqual(logRecords[0].eventName, "session.start")
  }

  func testSessionStartLogRecord() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.eventName, "session.start")
    XCTAssertNotNil(record.observedTimestamp, "Observed timestamp should be set")
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))

    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionStartApplyAfter() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.eventName, "session.start")
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionStartApplyBefore() {
    SessionEventInstrumentation.install()
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.eventName, "session.start")
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionEndApplyBefore() {
    SessionEventInstrumentation.install()
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.eventName, "session.end")
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionStartLogRecordWithPreviousId() {
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.eventName, "session.start")
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId2))

    XCTAssertEqual(record.attributes["session.previous_id"], AttributeValue.string(sessionId1))
  }

  func testSessionEndLogRecord() {
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertEqual(record.eventName, "session.end")
    XCTAssertNotNil(record.observedTimestamp, "Observed timestamp should be set")
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(Double(sessionExpired.duration!.toNanoseconds)))

    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testInstrumentationScopeName() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(SessionEventInstrumentation.instrumentationKey, "io.opentelemetry.sessions")
    XCTAssertEqual(logRecords.first?.instrumentationScopeInfo.name, "io.opentelemetry.sessions")
  }

  func testMultipleSessionsProcessedInOrderAfterinstrumentation() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 3)

    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(logRecords[0].eventName, "session.start")
    XCTAssertNil(logRecords[0].attributes["session.previous_id"])

    XCTAssertEqual(logRecords[1].attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(logRecords[1].eventName, "session.start")
    XCTAssertEqual(logRecords[1].attributes["session.previous_id"], AttributeValue.string(sessionId1))

    XCTAssertEqual(logRecords[2].attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(logRecords[2].eventName, "session.end")
  }

  func testMultipleSessionsProcessedInOrderBefore() {
    SessionEventInstrumentation.install()

    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 3)

    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(logRecords[0].eventName, "session.start")
    XCTAssertNil(logRecords[0].attributes["session.previous_id"])

    XCTAssertEqual(logRecords[1].attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(logRecords[1].eventName, "session.start")
    XCTAssertEqual(logRecords[1].attributes["session.previous_id"], AttributeValue.string(sessionId1))

    XCTAssertEqual(logRecords[2].attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(logRecords[2].eventName, "session.end")
  }

  // MARK: - Max Queue Size Tests

  func testMaxQueueSizeConstant() {
    XCTAssertEqual(SessionEventInstrumentation.maxQueueSize, 32)
  }

  func testQueueEnforcesMaxSize() {
    // Add sessions up to max capacity
    for i in 1 ... 32 {
      let session = Session(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      SessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 32)
    XCTAssertEqual(SessionEventInstrumentation.queue.first?.session.id, "session-1")
    XCTAssertEqual(SessionEventInstrumentation.queue.last?.session.id, "session-32")
  }

  func testQueueDropsNewEventsWhenExceedingMaxSize() {
    // Add sessions beyond max capacity
    for i in 1 ... 40 {
      let session = Session(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      SessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 32)
    XCTAssertEqual(SessionEventInstrumentation.queue.first?.session.id, "session-1")
    XCTAssertEqual(SessionEventInstrumentation.queue.last?.session.id, "session-32")
  }

  func testMaxQueueSizeWithMixedSessionTypes() {
    // Add mix of active and expired sessions beyond max capacity
    for i in 1 ... 40 {
      let session: Session
      let eventType: SessionEventType
      if i % 3 == 0 {
        // Every third session is expired
        session = Session(
          id: "session-\(i)",
          expireTime: Date().addingTimeInterval(-3600)
        )
        eventType = .end
      } else {
        session = Session(
          id: "session-\(i)",
          expireTime: Date().addingTimeInterval(3600)
        )
        eventType = .start
      }
      SessionEventInstrumentation.addSession(session: session, eventType: eventType)
    }

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 32)
    XCTAssertEqual(SessionEventInstrumentation.queue.first?.session.id, "session-1")
    XCTAssertEqual(SessionEventInstrumentation.queue.last?.session.id, "session-32")
  }

  func testQueueDoesNotEnforceMaxSizeAfterInstrumentationApplied() {
    SessionEventInstrumentation.install()
    let max: UInt8 = SessionEventInstrumentation.maxQueueSize + 1

    // Add sessions after instrumentation is applied
    for i in 1 ... max {
      let session = Session(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      SessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    // Queue should remain empty as sessions are processed immediately
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)

    // All sessions should be processed
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, Int(max))
  }

  func testProcessingQueuedSessionsAfterMaxSizeEnforcement() {
    // Add sessions beyond max capacity
    for i in 1 ... 40 {
      let session = Session(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      SessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 32)

    // Apply instrumentation to process queued sessions
    SessionEventInstrumentation.install()

    // Only the first 32 sessions should be processed (sessions 33-40 were dropped)
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 32)

    // Verify the first processed session is session-1 (first added)
    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string("session-1"))
    // Verify the last processed session is session-32 (last one that fit in queue)
    XCTAssertEqual(logRecords[31].attributes["session.id"], AttributeValue.string("session-32"))
  }

  // MARK: - SessionManager Integration Tests

  func testSessionManagerTenSessionChain() {
    SessionEventInstrumentation.install()
    let sessionManager = SessionManager(configuration: SessionConfig(sessionTimeout: 0))

    var sessions: [Session] = []

    // Create 10 sessions in sequence
    for _ in 1 ... 10 {
      sessions.append(sessionManager.getSession())
    }

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 19) // 1 start + 9*(end+start) = 1 + 18 = 19

    // Verify first session has no previous ID
    let firstStartRecord = logRecords.first { record in
      record.eventName == "session.start" &&
        record.attributes["session.id"] == AttributeValue.string(sessions[0].id)
    }
    XCTAssertNotNil(firstStartRecord)
    XCTAssertNil(firstStartRecord!.attributes["session.previous_id"])

    // Verify session chain linking
    for i in 1 ..< sessions.count {
      let sessionStartRecord = logRecords.first { record in
        record.eventName == "session.start" &&
          record.attributes["session.id"] == AttributeValue.string(sessions[i].id)
      }
      XCTAssertNotNil(sessionStartRecord)
      XCTAssertEqual(sessionStartRecord?.attributes["session.previous_id"], AttributeValue.string(sessions[i - 1].id))
    }
  }

  // MARK: - Explicit Event Type Tests

  func testAddSessionWithExplicitStartEventType() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    guard logRecords.count > 0 else {
      XCTFail("No log records found. isApplied: \(SessionEventInstrumentation.isApplied), queue: \(SessionEventInstrumentation.queue.count)")
      return
    }
    XCTAssertEqual(logRecords[0].eventName, "session.start")
    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
  }

  func testAddSessionWithExplicitEndEventType() {
    let sessionWithEndTime = Session(
      id: sessionIdExpired,
      expireTime: Date().addingTimeInterval(-3600),
      startTime: Date().addingTimeInterval(-7200)
    )

    SessionEventInstrumentation.addSession(session: sessionWithEndTime, eventType: .end)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].eventName, "session.end")
    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionIdExpired))
  }

  func testObservedTimestampIsSetOnSessionEvents() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.install()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)

    let record = logRecords[0]
    XCTAssertNotNil(record.observedTimestamp)
    XCTAssertNotNil(record.timestamp)

    // Verify the observed timestamp equals the timestamp
    XCTAssertNotEqual(record.observedTimestamp, record.timestamp)
  }

  func testQueueStoresEventType() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].eventType, .start)
    XCTAssertEqual(SessionEventInstrumentation.queue[1].eventType, .end)
  }

  func testDeprecatedConstructorCallsInstall() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    XCTAssertFalse(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)

    _ = SessionEventInstrumentation()

    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].eventName, "session.start")
  }

  func testDeprecatedSessionEventNotification() {
    XCTAssertEqual(SessionEventInstrumentation.sessionEventNotification, SessionEventNotification)
  }
}

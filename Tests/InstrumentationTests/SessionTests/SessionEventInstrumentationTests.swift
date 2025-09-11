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
    expireTime: Date().addingTimeInterval(-3600)
  )

  override func setUp() {
    super.setUp()

    startTime1 = Date()
    startTime2 = Date().addingTimeInterval(60)

    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = false

    logExporter = InMemoryLogRecordExporter()
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [SimpleLogRecordProcessor(logRecordExporter: logExporter)])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

    NotificationCenter.default.removeObserver(
      self,
      name: SessionEventInstrumentation.sessionEventNotification,
      object: nil
    )
  }

  override func tearDown() {
    super.tearDown()

    NotificationCenter.default.removeObserver(
      self,
      name: SessionEventInstrumentation.sessionEventNotification,
      object: nil
    )

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
    XCTAssertEqual(SessionEventInstrumentation.queue[0].eventType, .start)
  }

  func testInstrumentationEmptiesQueue() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    XCTAssertFalse(SessionEventInstrumentation.isApplied)

    _ = SessionEventInstrumentation()

    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testQueueDoesNotFillAfterApplied() {
    // XCTAssertFalse(SessionEventInstrumentation.isApplied)
    _ = SessionEventInstrumentation()

    SessionEventInstrumentation.addSession(session: session2, eventType: .start)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testNotificationPostedAfterInstrumentationApplied() {
    let expectation = XCTestExpectation(description: "Session notification posted")
    var receivedSessionEvent: SessionEvent?

    NotificationCenter.default.addObserver(
      forName: SessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedSessionEvent = notification.object as? SessionEvent
      expectation.fulfill()
    }

    _ = SessionEventInstrumentation()

    SessionEventInstrumentation.addSession(session: session1, eventType: .start)

    wait(for: [expectation], timeout: 0)

    XCTAssertNotNil(receivedSessionEvent)
    XCTAssertEqual(receivedSessionEvent?.session.id, sessionId1)
    XCTAssertEqual(receivedSessionEvent?.eventType, .start)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testMultipleInitializationDoesNotProcessQueueTwice() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    
    _ = SessionEventInstrumentation()
    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
    
    // Second initialization should not process queue again
    SessionEventInstrumentation.queue = [SessionEvent(session: sessionExpired, eventType: .end)]
    _ = SessionEventInstrumentation()
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1) // Queue unchanged
  }

  func testMultipleInitializationDoesNotAddDuplicateObservers() {
    _ = SessionEventInstrumentation()
    _ = SessionEventInstrumentation()
    
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
  }

  func testSessionStartLogRecord() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    
    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(startTime1.timeIntervalSince1970.toNanoseconds)))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionStartLogRecordWithPreviousId() {
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    
    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(startTime2.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(record.attributes["session.previous_id"], AttributeValue.string(sessionId1))
  }

  func testSessionEndLogRecord() {
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    
    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.end"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(Double(sessionExpired.startTime.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(record.attributes["session.end_time"], AttributeValue.double(Double(sessionExpired.endTime!.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(Double(sessionExpired.duration!.toNanoseconds)))
    XCTAssertNil(record.attributes["session.previous_id"])
  }
  
  func testInstrumentationScopeName() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.first?.instrumentationScopeInfo.name, "io.opentelemetry.sessions")
  }
  
  func testQueueSizeLimit() {
    // Fill queue to max capacity
    for i in 0..<Int(SessionEventInstrumentation.maxQueueSize) {
      let session = Session(id: "session-\(i)", expireTime: Date().addingTimeInterval(3600))
      SessionEventInstrumentation.addSession(session: session, eventType: .start)
    }
    
    XCTAssertEqual(SessionEventInstrumentation.queue.count, Int(SessionEventInstrumentation.maxQueueSize))
    
    // Try to add one more - should be dropped
    let extraSession = Session(id: "extra-session", expireTime: Date().addingTimeInterval(3600))
    SessionEventInstrumentation.addSession(session: extraSession, eventType: .start)
    
    // Queue should still be at max size, extra session dropped
    XCTAssertEqual(SessionEventInstrumentation.queue.count, Int(SessionEventInstrumentation.maxQueueSize))
    
    // Verify the extra session was not added
    let sessionIds = SessionEventInstrumentation.queue.map { $0.session.id }
    XCTAssertFalse(sessionIds.contains("extra-session"))
  }
  
  func testNotificationNotPostedBeforeInstrumentationApplied() {
    let expectation = XCTestExpectation(description: "Session notification posted")
    expectation.isInverted = true

    NotificationCenter.default.addObserver(
      forName: SessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { _ in
      expectation.fulfill()
    }

    SessionEventInstrumentation.addSession(session: session1, eventType: .start)

    wait(for: [expectation], timeout: 0.1)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
  }
  
  func testSessionEventProcessingOrder() {
    // Test both before and after instrumentation application
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    _ = SessionEventInstrumentation()
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 2)

    // Verify session start record
    let startRecord = logRecords[0]
    XCTAssertEqual(startRecord.body, AttributeValue.string("session.start"))
    XCTAssertEqual(startRecord.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(startRecord.attributes["session.start_time"], AttributeValue.double(Double(session1.startTime.timeIntervalSince1970.toNanoseconds)))
    XCTAssertNil(startRecord.attributes["session.previous_id"])

    // Verify session end record
    let endRecord = logRecords[1]
    XCTAssertEqual(endRecord.body, AttributeValue.string("session.end"))
    XCTAssertEqual(endRecord.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(endRecord.attributes["session.start_time"], AttributeValue.double(Double(sessionExpired.startTime.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(endRecord.attributes["session.end_time"], AttributeValue.double(Double(sessionExpired.endTime!.timeIntervalSince1970.toNanoseconds)))
    XCTAssertEqual(endRecord.attributes["session.duration"], AttributeValue.double(Double(sessionExpired.duration!.toNanoseconds)))
  }
  
  func testMultipleSessionsProcessedInOrderAfterInstrumentation() {
    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    _ = SessionEventInstrumentation()

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 3)

    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
    XCTAssertNil(logRecords[0].attributes["session.previous_id"])

    XCTAssertEqual(logRecords[1].attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(logRecords[1].body, AttributeValue.string("session.start"))
    XCTAssertEqual(logRecords[1].attributes["session.previous_id"], AttributeValue.string(sessionId1))

    XCTAssertEqual(logRecords[2].attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(logRecords[2].body, AttributeValue.string("session.end"))
  }

  func testMultipleSessionsProcessedInOrderBefore() {
    _ = SessionEventInstrumentation()

    SessionEventInstrumentation.addSession(session: session1, eventType: .start)
    SessionEventInstrumentation.addSession(session: session2, eventType: .start)
    SessionEventInstrumentation.addSession(session: sessionExpired, eventType: .end)

    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 3)

    XCTAssertEqual(logRecords[0].attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
    XCTAssertNil(logRecords[0].attributes["session.previous_id"])

    XCTAssertEqual(logRecords[1].attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(logRecords[1].body, AttributeValue.string("session.start"))
    XCTAssertEqual(logRecords[1].attributes["session.previous_id"], AttributeValue.string(sessionId1))

    XCTAssertEqual(logRecords[2].attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(logRecords[2].body, AttributeValue.string("session.end"))
  }
  
  func testMaxQueueSizeConstant() {
    XCTAssertEqual(SessionEventInstrumentation.maxQueueSize, 32)
  }

  func testQueueSizeEnforcement() {
    XCTAssertEqual(SessionEventInstrumentation.maxQueueSize, 32)
    
    // Test queue drops events when exceeding max size with mixed event types
    for i in 1...40 {
      let eventType: SessionEventType = (i % 3 == 0) ? .end : .start
      let session = Session(id: "session-\(i)", expireTime: Date().addingTimeInterval(3600))
      SessionEventInstrumentation.addSession(session: session, eventType: eventType)
    }

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 32)
    XCTAssertEqual(SessionEventInstrumentation.queue.first?.session.id, "session-1")
    XCTAssertEqual(SessionEventInstrumentation.queue.last?.session.id, "session-32")
  }

  func testQueueDoesNotEnforceMaxSizeAfterInstrumentationApplied() {
    _ = SessionEventInstrumentation()
    let max: UInt8 = SessionEventInstrumentation.maxQueueSize + 1

    // Add sessions after instrumentation is applied
    for i in 1...max {
      let session = Session(
        id: "session-\(i)",
        expireTime: Date().addingTimeInterval(3600)
      )
      SessionEventInstrumentation.addSession(session: session, eventType: .start)
    }

    // Queue should remain empty as sessions are processed via notifications
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)

    // All sessions should be processed
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, Int(max))
  }
  
  func testSessionEndEventWithActiveSession() {
    // Test session end event with active session (no endTime/duration)
    let activeSession = Session(id: "active-session", expireTime: Date().addingTimeInterval(3600))
    
    _ = SessionEventInstrumentation()
    SessionEventInstrumentation.addSession(session: activeSession, eventType: .end)
    
    // Should not create log record for active session end event
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 0)
  }
}
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
    SessionEventInstrumentation.addSession(session: session1)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    XCTAssertEqual(SessionEventInstrumentation.queue[0].id, sessionId1)
  }

  func testInstrumentationEmptiesQueue() {
    SessionEventInstrumentation.addSession(session: session1)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1)
    SessionEventInstrumentation.addSession(session: session2)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    XCTAssertFalse(SessionEventInstrumentation.isApplied)

    _ = SessionEventInstrumentation()

    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testQueueDoesNotFillAfterApplied() {
    // XCTAssertFalse(SessionEventInstrumentation.isApplied)
    _ = SessionEventInstrumentation()

    SessionEventInstrumentation.addSession(session: session2)

    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testNotificationPostedAfterInstrumentationApplied() {
    let expectation = XCTestExpectation(description: "Session notification posted")
    var receivedSession: Session?

    NotificationCenter.default.addObserver(
      forName: SessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedSession = notification.object as? Session
      expectation.fulfill()
    }

    _ = SessionEventInstrumentation()

    SessionEventInstrumentation.addSession(session: session1)

    wait(for: [expectation], timeout: 0)

    XCTAssertNotNil(receivedSession)
    XCTAssertEqual(receivedSession?.id, sessionId1)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
  }

  func testMultipleInitializationDoesNotProcessQueueTwice() {
    SessionEventInstrumentation.addSession(session: session1)
    SessionEventInstrumentation.addSession(session: session2)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    
    _ = SessionEventInstrumentation()
    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 0)
    
    // Second initialization should not process queue again
    SessionEventInstrumentation.queue = [sessionExpired]
    _ = SessionEventInstrumentation()
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 1) // Queue unchanged
  }

  func testMultipleInitializationDoesNotAddDuplicateObservers() {
    _ = SessionEventInstrumentation()
    _ = SessionEventInstrumentation()
    
    SessionEventInstrumentation.addSession(session: session1)
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    XCTAssertEqual(logRecords[0].body, AttributeValue.string("session.start"))
  }

  func testSessionStartLogRecord() {
    SessionEventInstrumentation.addSession(session: session1)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    
    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId1))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(startTime1.timeIntervalSince1970))
    XCTAssertNil(record.attributes["session.previous_id"])
  }

  func testSessionStartLogRecordWithPreviousId() {
    SessionEventInstrumentation.addSession(session: session2)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    
    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.start"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionId2))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(startTime2.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.previous_id"], AttributeValue.string(sessionId1))
  }

  func testSessionEndLogRecord() {
    SessionEventInstrumentation.addSession(session: sessionExpired)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.count, 1)
    
    let record = logRecords[0]
    XCTAssertEqual(record.body, AttributeValue.string("session.end"))
    XCTAssertEqual(record.attributes["session.id"], AttributeValue.string(sessionIdExpired))
    XCTAssertEqual(record.attributes["session.start_time"], AttributeValue.double(sessionExpired.startTime.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.end_time"], AttributeValue.double(sessionExpired.endTime!.timeIntervalSince1970))
    XCTAssertEqual(record.attributes["session.duration"], AttributeValue.double(sessionExpired.duration!))
    XCTAssertNil(record.attributes["session.previous_id"])
  }
  
  func testInstrumentationScopeName() {
    SessionEventInstrumentation.addSession(session: session1)
    _ = SessionEventInstrumentation()
    
    let logRecords = logExporter.getFinishedLogRecords()
    XCTAssertEqual(logRecords.first?.instrumentationScopeInfo.name, "io.opentelemetry.sessions")
  }
}
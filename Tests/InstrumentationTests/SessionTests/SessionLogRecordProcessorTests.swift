import XCTest
import OpenTelemetryApi
@testable import Sessions
@testable import OpenTelemetrySdk

final class SessionLogRecordProcessorTests: XCTestCase {
  var mockSessionManager: MockSessionManager!
  var mockNextProcessor: MockLogRecordProcessor!
  var logRecordProcessor: SessionLogRecordProcessor!
  var testLogRecord: ReadableLogRecord!

  override func setUp() {
    super.setUp()
    mockSessionManager = MockSessionManager()
    mockNextProcessor = MockLogRecordProcessor()
    logRecordProcessor = SessionLogRecordProcessor(nextProcessor: mockNextProcessor, sessionManager: mockSessionManager)

    testLogRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: ["original.key": AttributeValue.string("original.value")]
    )
  }

  func testOnEmitAddsSessionAttributes() {
    let expectedSessionId = "test-session-123"
    mockSessionManager.sessionId = expectedSessionId

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }
  }

  func testOnEmitPreservesOriginalAttributes() {
    mockSessionManager.sessionId = "test-session"

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(originalValue) = enhancedRecord.attributes["original.key"] {
      XCTAssertEqual(originalValue, "original.value")
    } else {
      XCTFail("Expected original.key attribute to be preserved")
    }

    XCTAssertEqual(enhancedRecord.resource.attributes, testLogRecord.resource.attributes)
    XCTAssertEqual(enhancedRecord.instrumentationScopeInfo.name, testLogRecord.instrumentationScopeInfo.name)
    XCTAssertEqual(enhancedRecord.timestamp, testLogRecord.timestamp)
    XCTAssertEqual(enhancedRecord.observedTimestamp, testLogRecord.observedTimestamp)
    XCTAssertEqual(enhancedRecord.severity, testLogRecord.severity)
    XCTAssertEqual(enhancedRecord.body?.description, testLogRecord.body?.description)
    XCTAssertEqual(enhancedRecord.spanContext, testLogRecord.spanContext)
  }

  func testOnEmitAddsPreviousSessionId() {
    let expectedSessionId = "current-session-123"
    let expectedPreviousSessionId = "previous-session-456"
    mockSessionManager.sessionId = expectedSessionId
    mockSessionManager.previousSessionId = expectedPreviousSessionId

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    if case let .string(previousSessionId) = enhancedRecord.attributes[SessionConstants.previousId] {
      XCTAssertEqual(previousSessionId, expectedPreviousSessionId)
    } else {
      XCTFail("Expected session.previous_id attribute to be a string value")
    }
  }

  func testOnEmitWithoutPreviousSessionId() {
    let expectedSessionId = "current-session-123"
    mockSessionManager.sessionId = expectedSessionId
    mockSessionManager.previousSessionId = nil

    logRecordProcessor.onEmit(logRecord: testLogRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    XCTAssertNil(enhancedRecord.attributes[SessionConstants.previousId], "Previous session ID should not be set when nil")
  }

  func testOnEmitWithDifferentSessionIds() {
    mockSessionManager.sessionId = "session-1"
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    mockSessionManager.sessionId = "session-2"
    logRecordProcessor.onEmit(logRecord: testLogRecord)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 2)

    if case let .string(sessionId1) = mockNextProcessor.receivedLogRecords[0].attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId1, "session-1")
    } else {
      XCTFail("Expected first log record to have session-1")
    }

    if case let .string(sessionId2) = mockNextProcessor.receivedLogRecords[1].attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId2, "session-2")
    } else {
      XCTFail("Expected second log record to have session-2")
    }
  }

  func testShutdownReturnsSuccess() {
    let result = logRecordProcessor.shutdown(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testForceFlushReturnsSuccess() {
    let result = logRecordProcessor.forceFlush(explicitTimeout: 5.0)
    XCTAssertEqual(result, .success)
  }

  func testSessionStartEventPreservesExistingAttributes() {
    let sessionStartRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("session.start"),
      attributes: [
        SessionConstants.id: AttributeValue.string("existing-session-123"),
        SessionConstants.previousId: AttributeValue.string("existing-previous-456")
      ]
    )

    mockSessionManager.sessionId = "current-session-999"
    logRecordProcessor.onEmit(logRecord: sessionStartRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId, "existing-session-123", "Should preserve existing session ID for session.start")
    } else {
      XCTFail("Expected existing session.id to be preserved")
    }

    if case let .string(previousId) = enhancedRecord.attributes[SessionConstants.previousId] {
      XCTAssertEqual(previousId, "existing-previous-456", "Should preserve existing previous session ID")
    } else {
      XCTFail("Expected existing session.previous_id to be preserved")
    }
  }

  func testSessionEndEventPreservesExistingAttributes() {
    let sessionEndRecord = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("session.end"),
      attributes: [
        SessionConstants.id: AttributeValue.string("ending-session-789"),
        "session.duration": AttributeValue.double(123.45)
      ]
    )

    mockSessionManager.sessionId = "current-session-999"
    logRecordProcessor.onEmit(logRecord: sessionEndRecord)

    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    if case let .string(sessionId) = enhancedRecord.attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId, "ending-session-789", "Should preserve existing session ID for session.end")
    } else {
      XCTFail("Expected existing session.id to be preserved")
    }

    if case let .double(duration) = enhancedRecord.attributes["session.duration"] {
      XCTAssertEqual(duration, 123.45, "Should preserve existing session.duration")
    } else {
      XCTFail("Expected existing session.duration to be preserved")
    }
  }

  func testDataIsPreserved() {
    let logRecordWithEventName = ReadableLogRecord(
      resource: Resource(attributes: [:]),
      instrumentationScopeInfo: InstrumentationScopeInfo(),
      timestamp: Date(),
      observedTimestamp: Date(),
      spanContext: nil,
      severity: .info,
      body: AttributeValue.string("Test log message"),
      attributes: ["test.key": AttributeValue.string("test.value")],
      eventName: "user.login"
    )

    mockSessionManager.sessionId = "test-session-123"
    logRecordProcessor.onEmit(logRecord: logRecordWithEventName)

    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 1)
    let enhancedRecord = mockNextProcessor.receivedLogRecords[0]

    // Verify all fields are preserved
    XCTAssertEqual(enhancedRecord.eventName, "user.login", "EventName should be preserved")
    XCTAssertEqual(enhancedRecord.resource.attributes, logRecordWithEventName.resource.attributes)
    XCTAssertEqual(enhancedRecord.instrumentationScopeInfo.name, logRecordWithEventName.instrumentationScopeInfo.name)
    XCTAssertEqual(enhancedRecord.timestamp, logRecordWithEventName.timestamp)
    XCTAssertEqual(enhancedRecord.observedTimestamp, logRecordWithEventName.observedTimestamp)
    XCTAssertEqual(enhancedRecord.severity, logRecordWithEventName.severity)
    XCTAssertEqual(enhancedRecord.body?.description, logRecordWithEventName.body?.description)
    XCTAssertEqual(enhancedRecord.spanContext, logRecordWithEventName.spanContext)
    
    // Verify session attributes were added
    if case let .string(sessionId) = enhancedRecord.attributes[SessionConstants.id] {
      XCTAssertEqual(sessionId, "test-session-123")
    } else {
      XCTFail("Expected session.id attribute to be added")
    }
    
    // Verify original attributes preserved
    if case let .string(testValue) = enhancedRecord.attributes["test.key"] {
      XCTAssertEqual(testValue, "test.value")
    } else {
      XCTFail("Expected original attributes to be preserved")
    }
    
    // Verify total attribute count (original + session attributes)
    XCTAssertEqual(enhancedRecord.attributes.count, 2, "Should have original attribute + session.id")
  }

  func testConcurrentOnEmitThreadSafety() {
    let mockNextProcessor = MockLogRecordProcessor()
    let expectation = XCTestExpectation(description: "Concurrent processing")
    let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
    let group = DispatchGroup()
    
    for i in 0..<10 {
      group.enter()
      queue.async {
        let sessionManager = MockSessionManager()
        sessionManager.sessionId = "session-\(i)"
        let processor = SessionLogRecordProcessor(nextProcessor: mockNextProcessor, sessionManager: sessionManager)
        processor.onEmit(logRecord: self.testLogRecord)
        group.leave()
      }
    }
    
    group.notify(queue: .main) {
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
    
    XCTAssertEqual(mockNextProcessor.receivedLogRecords.count, 10)
    for record in mockNextProcessor.receivedLogRecords {
      XCTAssertTrue(record.attributes.keys.contains(SessionConstants.id))
    }
  }
}

// MARK: - Mock Classes

class MockLogRecordProcessor: LogRecordProcessor {
  private let queue = DispatchQueue(label: "MockLogRecordProcessor")
  private var _receivedLogRecords: [ReadableLogRecord] = []
  
  var receivedLogRecords: [ReadableLogRecord] {
    return queue.sync { _receivedLogRecords }
  }

  func onEmit(logRecord: ReadableLogRecord) {
    queue.sync {
      _receivedLogRecords.append(logRecord)
    }
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return .success
  }
}
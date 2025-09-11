import XCTest
import OpenTelemetryApi
@testable import Sessions
@testable import OpenTelemetrySdk

final class SessionSpanProcessorTests: XCTestCase {
  var mockSessionManager: MockSessionManager!
  var spanProcessor: SessionSpanProcessor!
  var mockSpan: MockReadableSpan!

  override func setUp() {
    super.setUp()
    mockSessionManager = MockSessionManager()
    spanProcessor = SessionSpanProcessor(sessionManager: mockSessionManager)
    mockSpan = MockReadableSpan()
  }

  func testInitialization() {
    XCTAssertTrue(spanProcessor.isStartRequired)
    XCTAssertFalse(spanProcessor.isEndRequired)
  }

  func testOnStartAddsSessionId() {
    let expectedSessionId = "test-session-123"
    mockSessionManager.sessionId = expectedSessionId

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    if case let .string(sessionId) = mockSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }
  }

  func testOnStartWithDifferentSessionIds() {
    mockSessionManager.sessionId = "session-1"
    spanProcessor.onStart(parentContext: nil, span: mockSpan)
    if case let .string(sessionId) = mockSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, "session-1")
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    let anotherSpan = MockReadableSpan()
    mockSessionManager.sessionId = "session-2"
    spanProcessor.onStart(parentContext: nil, span: anotherSpan)
    if case let .string(sessionId) = anotherSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, "session-2")
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }
  }

  func testOnEndDoesNothing() {
    spanProcessor.onEnd(span: mockSpan)
    // No assertions needed - just verify it doesn't crash
  }

  func testShutdownDoesNothing() {
    spanProcessor.shutdown(explicitTimeout: 5.0)
    // No assertions needed - just verify it doesn't crash
  }

  func testForceFlushDoesNothing() {
    spanProcessor.forceFlush(timeout: 5.0)
    // No assertions needed - just verify it doesn't crash
  }

  func testOnStartAddsPreviousSessionId() {
    let expectedSessionId = "current-session-123"
    let expectedPreviousSessionId = "previous-session-456"
    mockSessionManager.sessionId = expectedSessionId
    mockSessionManager.previousSessionId = expectedPreviousSessionId

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    if case let .string(sessionId) = mockSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    if case let .string(previousSessionId) = mockSpan.capturedAttributes["session.previous_id"] {
      XCTAssertEqual(previousSessionId, expectedPreviousSessionId)
    } else {
      XCTFail("Expected session.previous_id attribute to be a string value")
    }
  }

  func testOnStartWithoutPreviousSessionId() {
    let expectedSessionId = "current-session-123"
    mockSessionManager.sessionId = expectedSessionId
    mockSessionManager.previousSessionId = nil

    spanProcessor.onStart(parentContext: nil, span: mockSpan)

    if case let .string(sessionId) = mockSpan.capturedAttributes["session.id"] {
      XCTAssertEqual(sessionId, expectedSessionId)
    } else {
      XCTFail("Expected session.id attribute to be a string value")
    }

    XCTAssertNil(mockSpan.capturedAttributes["session.previous_id"], "Previous session ID should not be set when nil")
  }
  
  func testInitializationWithNilSessionManager() {
    let processor = SessionSpanProcessor()
    XCTAssertTrue(processor.isStartRequired)
    XCTAssertFalse(processor.isEndRequired)
  }
}

// MARK: - Mock Classes

class MockSessionManager: SessionManager {
  var sessionId: String = "default-session-id"
  var previousSessionId: String?
  var startTime: Date = .init()

  override func getSession() -> Session {
    return Session(
      id: sessionId,
      expireTime: Date(timeIntervalSinceNow: 1800),
      previousId: previousSessionId,
      startTime: startTime
    )
  }
}

class MockReadableSpan: ReadableSpan {
  var capturedAttributes: [String: AttributeValue] = [:]

  var hasEnded: Bool = false
  var latency: TimeInterval = 0
  var kind: SpanKind = .client
  var instrumentationScopeInfo = InstrumentationScopeInfo()
  var name: String = "MockSpan"
  var context: SpanContext = .create(traceId: TraceId.random(), spanId: SpanId.random(), traceFlags: TraceFlags(), traceState: TraceState())
  var isRecording: Bool = true
  var status: Status = .unset
  var description: String = "MockReadableSpan"
  
  func getAttributes() -> [String: AttributeValue] {
    return capturedAttributes
  }
  
  func setAttributes(_ attributes: [String: AttributeValue]) {
    capturedAttributes.merge(attributes) { _, new in new }
  }

  func end() {}
  func end(time: Date) {}

  func toSpanData() -> SpanData {
    return SpanData(traceId: context.traceId,
                    spanId: context.spanId,
                    traceFlags: context.traceFlags,
                    traceState: TraceState(),
                    resource: Resource(attributes: [String: AttributeValue]()),
                    instrumentationScope: InstrumentationScopeInfo(),
                    name: name,
                    kind: kind,
                    startTime: Date(),
                    endTime: Date(),
                    hasRemoteParent: false)
  }

  func updateName(name: String) {
    self.name = name
  }

  func setAttribute(key: String, value: AttributeValue?) {
    if let value = value {
      capturedAttributes[key] = value
    }
  }

  func addEvent(name: String) {}
  func addEvent(name: String, attributes: [String: AttributeValue]) {}
  func addEvent(name: String, timestamp: Date) {}
  func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}
  func recordException(_ exception: SpanException) {}
  func recordException(_ exception: any SpanException, timestamp: Date) {}
  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue]) {}
  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue], timestamp: Date) {}
}
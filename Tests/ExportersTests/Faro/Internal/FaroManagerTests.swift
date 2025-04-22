/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
import OpenTelemetryApi
@testable import FaroExporter
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetrySdk

final class FaroManagerTests: XCTestCase {
  var mockTransport: MockFaroTransport!
  var mockSessionManager: MockFaroSessionManager!
  var mockDateProvider: MockDateProvider!
  var appInfo: FaroAppInfo!
  var sut: FaroManager!

  override func setUp() {
    super.setUp()

    mockTransport = MockFaroTransport()
    mockSessionManager = MockFaroSessionManager()
    mockDateProvider = MockDateProvider()
    appInfo = FaroAppInfo(name: "TestApp", namespace: "com.test", version: "1.0.0",
                          environment: "test", bundleId: "com.test.app", release: "1.0.0")

    sut = FaroManager(appInfo: appInfo,
                      transport: mockTransport,
                      sessionManager: mockSessionManager,
                      dateProvider: mockDateProvider,
                      config: FaroManagerConfig(flushInterval: 0.01))
  }

  override func tearDown() {
    mockTransport = nil
    mockSessionManager = nil
    mockDateProvider = nil
    appInfo = nil
    sut = nil

    super.tearDown()
  }

  // MARK: - Initialization Tests

  func testInitSendsSessionStartEvent() {
    // Create an expectation for the send operation
    let expectation = XCTestExpectation(description: "Wait for session start event")
    mockTransport.sendExpectation = expectation

    // Wait for the send operation to complete
    wait(for: [expectation], timeout: 3.0)

    // Verify that a session start event was sent during initialization
    XCTAssertEqual(mockTransport.sentPayloads.count, 1, "Should have sent session start event during init")

    let payload = mockTransport.sentPayloads[0]
    XCTAssertNotNil(payload.events, "Events should not be nil")
    XCTAssertEqual(payload.events?.count, 1, "Should be exactly one event")
    XCTAssertEqual(payload.events?[0].name, "session_start", "Event should be session_start")
  }

  // MARK: - Push Events Tests

  func testPushEvents() {
    // Clear initial session start event
    mockTransport.sentPayloads = []

    // Create test events
    let event1 = createTestEvent(name: "test_event_1")
    let event2 = createTestEvent(name: "test_event_2")

    // Set up expectation for the send operation
    let expectation = XCTestExpectation(description: "Wait for flush")
    mockTransport.sendExpectation = expectation

    // Push events
    sut.pushEvents(events: [event1, event2])

    // Wait for the send operation to complete
    wait(for: [expectation], timeout: 3.0)

    // Verify events were sent
    XCTAssertEqual(mockTransport.sentPayloads.count, 1, "Should have sent events in one payload")

    let payload = mockTransport.sentPayloads[0]
    XCTAssertNotNil(payload.events, "Events should not be nil")

    // The payload should contain our 2 events plus the session_start event (3 total)
    XCTAssertEqual(payload.events?.count, 3, "Should have sent 3 events (including session_start)")

    // Verify our specific events are in the payload
    XCTAssertTrue(payload.events?.contains(where: { $0.name == "test_event_1" }) ?? false, "Should contain test_event_1")
    XCTAssertTrue(payload.events?.contains(where: { $0.name == "test_event_2" }) ?? false, "Should contain test_event_2")
    XCTAssertTrue(payload.events?.contains(where: { $0.name == "session_start" }) ?? false, "Should contain session_start")
  }

  // MARK: - Push Logs Tests

  func testPushLogs() {
    // Clear initial session start event
    mockTransport.sentPayloads = []

    // Create test logs
    let log1 = createTestLog(message: "Test log 1")
    let log2 = createTestLog(message: "Test log 2")

    // Set up expectation for the send operation
    let expectation = XCTestExpectation(description: "Wait for flush")
    mockTransport.sendExpectation = expectation

    // Push logs
    sut.pushLogs([log1, log2])

    // Wait for the send operation to complete
    wait(for: [expectation], timeout: 3.0)

    // Verify logs were sent
    XCTAssertEqual(mockTransport.sentPayloads.count, 1, "Should have sent logs in one payload")

    let payload = mockTransport.sentPayloads[0]
    XCTAssertNotNil(payload.logs, "Logs should not be nil")
    XCTAssertEqual(payload.logs?.count, 2, "Should have sent 2 logs")
    XCTAssertEqual(payload.logs?[0].message, "Test log 1", "First log message should match")
    XCTAssertEqual(payload.logs?[1].message, "Test log 2", "Second log message should match")
  }

  // MARK: - Push Spans Tests

  func testPushSpans() {
    // Clear initial session start event
    mockTransport.sentPayloads = []

    // Create test spans
    let span1 = createTestSpan(name: "test_span_1")
    let span2 = createTestSpan(name: "test_span_2")

    // Set up expectation for the send operation
    let expectation = XCTestExpectation(description: "Wait for flush")
    mockTransport.sendExpectation = expectation

    // Push spans
    sut.pushSpans([span1, span2])

    // Wait for the send operation to complete
    wait(for: [expectation], timeout: 3.0)

    // Verify spans were sent
    XCTAssertEqual(mockTransport.sentPayloads.count, 1, "Should have sent spans in one payload")

    let payload = mockTransport.sentPayloads[0]
    XCTAssertNotNil(payload.traces, "Traces should not be nil")

    // Extract span names from the proto structure
    guard let traces = payload.traces else {
      XCTFail("Traces should not be nil")
      return
    }

    // Navigate through the proto structure to get span names
    let spanNames = traces.resourceSpans.flatMap { resourceSpan in
      resourceSpan.scopeSpans.flatMap { scopeSpan in
        scopeSpan.spans.map(\.name)
      }
    }

    // Verify our specific spans are in the payload
    XCTAssertEqual(spanNames.count, 2, "Should have 2 spans")
    XCTAssertTrue(spanNames.contains("test_span_1"), "Should contain test_span_1")
    XCTAssertTrue(spanNames.contains("test_span_2"), "Should contain test_span_2")
  }

  // MARK: - Multiple Telemetry Types Test

  func testPushMultipleTelemetryTypes() {
    // Clear initial session start event
    mockTransport.sentPayloads = []

    // Create test data
    let event = createTestEvent(name: "test_event")
    let log = createTestLog(message: "Test log")
    let span = createTestSpan(name: "test_span")

    // Set up expectation for the send operation
    let expectation = XCTestExpectation(description: "Wait for flush")
    mockTransport.sendExpectation = expectation

    // Push different telemetry types
    sut.pushEvents(events: [event])
    sut.pushLogs([log])
    sut.pushSpans([span])

    // Wait for the send operation to complete
    wait(for: [expectation], timeout: 3.0)

    // Verify all telemetry was sent in a single payload
    XCTAssertEqual(mockTransport.sentPayloads.count, 1, "Should have sent all telemetry in one payload")

    let payload = mockTransport.sentPayloads[0]
    XCTAssertNotNil(payload.events, "Events should not be nil")

    // The payload should contain our event plus the session_start event (2 total)
    XCTAssertEqual(payload.events?.count, 2, "Should have sent 2 events (including session_start)")
    XCTAssertTrue(payload.events?.contains(where: { $0.name == "test_event" }) ?? false, "Should contain test_event")
    XCTAssertTrue(payload.events?.contains(where: { $0.name == "session_start" }) ?? false, "Should contain session_start")

    XCTAssertNotNil(payload.logs, "Logs should not be nil")
    XCTAssertEqual(payload.logs?.count, 1, "Should have sent 1 log")
    XCTAssertEqual(payload.logs?[0].message, "Test log", "Log message should match")

    XCTAssertNotNil(payload.traces, "Traces should not be nil")

    // Extract span names from the proto structure
    guard let traces = payload.traces else {
      XCTFail("Traces should not be nil")
      return
    }

    // Navigate through the proto structure to get span names
    let spanNames = traces.resourceSpans.flatMap { resourceSpan in
      resourceSpan.scopeSpans.flatMap { scopeSpan in
        scopeSpan.spans.map(\.name)
      }
    }

    // Verify our specific span is in the payload
    XCTAssertEqual(spanNames.count, 1, "Should have 1 span")
    XCTAssertTrue(spanNames.contains("test_span"), "Should contain test_span")
  }

  // MARK: - Error Handling Tests

  func testTransportErrorRetainsData() {
    // Clear initial session start event
    mockTransport.sentPayloads = []

    // Configure transport to fail
    mockTransport.failNextSend()

    // Create an expectation for the first send operation
    let firstSendExpectation = XCTestExpectation(description: "Wait for first send")
    mockTransport.sendExpectation = firstSendExpectation

    // Create and push a test event
    let event = createTestEvent(name: "test_event")
    sut.pushEvents(events: [event])

    // Wait for the first send operation to complete (which will fail)
    wait(for: [firstSendExpectation], timeout: 3.0)

    // Verify first attempt was made
    XCTAssertEqual(mockTransport.sentPayloads.count, 1, "Should have attempted to send first payload")

    // Reset transport to succeed for next attempt
    mockTransport.sendResult = .success(())

    // Create a second expectation for the second send operation
    let secondSendExpectation = XCTestExpectation(description: "Wait for second send")
    mockTransport.sendExpectation = secondSendExpectation

    // Push another event to trigger another flush
    let event2 = createTestEvent(name: "second_event")
    sut.pushEvents(events: [event2])

    // Wait for the second send operation to complete (which should succeed)
    wait(for: [secondSendExpectation], timeout: 3.0)

    // Verify that both events were sent in the second payload
    XCTAssertEqual(mockTransport.sentPayloads.count, 2, "Should have attempted to send two payloads")

    let secondPayload = mockTransport.sentPayloads[1]
    XCTAssertNotNil(secondPayload.events, "Events should not be nil")

    // The payload should contain both of our events plus session_start
    XCTAssertEqual(secondPayload.events?.count, 3, "Should have sent 3 events (including session_start)")

    // Verify our specific events are in the payload
    XCTAssertTrue(secondPayload.events?.contains(where: { $0.name == "test_event" }) ?? false, "Should contain test_event")
    XCTAssertTrue(secondPayload.events?.contains(where: { $0.name == "second_event" }) ?? false, "Should contain second_event")
    XCTAssertTrue(secondPayload.events?.contains(where: { $0.name == "session_start" }) ?? false, "Should contain session_start")
  }

  // MARK: - Session Change Tests

  func testSessionChangeCallback() {
    // First, wait for the initial session start event from the FaroManager initialization
    let initialExpectation = XCTestExpectation(description: "Wait for initial session start event")
    mockTransport.sendExpectation = initialExpectation

    // Recreate the manager to trigger a new initial session start
    sut = FaroManager(appInfo: appInfo,
                      transport: mockTransport,
                      sessionManager: mockSessionManager,
                      dateProvider: mockDateProvider)

    // Wait for the initial session start event to be sent
    wait(for: [initialExpectation], timeout: 3.0)

    // Store the count of payloads after initialization
    let initialPayloadCount = mockTransport.sentPayloads.count
    XCTAssertGreaterThan(initialPayloadCount, 0, "Should have at least one payload from initialization")

    // Now set up expectation for the second send operation that will happen after session change
    let sessionChangeExpectation = XCTestExpectation(description: "Wait for session change event")
    mockTransport.sendExpectation = sessionChangeExpectation

    // Simulate session change
    mockSessionManager.onSessionIdChanged?("old-session-id", "new-session-id")

    // Wait for the session change event to be sent
    wait(for: [sessionChangeExpectation], timeout: 3.0)

    // Verify that a new session start event was sent
    XCTAssertEqual(mockTransport.sentPayloads.count, initialPayloadCount + 1,
                   "Should have one more payload after session change")

    // Get the latest payload (from the session change)
    let latestPayload = mockTransport.sentPayloads.last!
    XCTAssertNotNil(latestPayload.events, "Events should not be nil")

    // Verify there's a session_start event in the latest payload
    let sessionStartEvents = latestPayload.events?.filter { $0.name == "session_start" } ?? []
    XCTAssertFalse(sessionStartEvents.isEmpty, "Latest payload should contain a session_start event")
  }

  // MARK: - Test Helpers

  private func createTestEvent(name: String) -> FaroEvent {
    let currentDate = mockDateProvider.currentDate()
    return FaroEvent(name: name, attributes: ["test": "value"], timestamp: mockDateProvider.iso8601String(from: currentDate), dateTimestamp: currentDate, trace: nil)
  }

  private func createTestLog(message: String) -> FaroLog {
    let currentDate = mockDateProvider.currentDate()
    let timestamp = mockDateProvider.iso8601String(from: currentDate)
    return FaroLog(timestamp: timestamp, dateTimestamp: currentDate, level: .info, message: message, context: ["test": "value"], trace: nil)
  }

  private func createTestSpan(name: String,
                              kind: SpanKind = .internal,
                              attributes: [String: AttributeValue] = ["test": AttributeValue.string("value")],
                              startTime: Date? = nil,
                              endTime: Date? = nil) -> SpanData {
    let traceId = TraceId.random()
    let spanId = SpanId.random()
    let start = startTime ?? Date()
    let end = endTime ?? Date(timeIntervalSinceNow: 0.1)

    var span = SpanData(
      traceId: traceId,
      spanId: spanId,
      name: name,
      kind: kind,
      startTime: start,
      endTime: end
    )
    span.settingAttributes(attributes)
    span.settingTotalAttributeCount(attributes.count)
    return span
  }
}

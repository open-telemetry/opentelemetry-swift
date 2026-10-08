/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

// The scenario shortens the session timeout, emits the root/child spans, the
// log record and the network requests in the first session, then lets it
// expire before emitting the second-session span. The app's own Hacker News
// requests can start further sessions in between, so the assertions check the
// shape of the session chain rather than an exact number of sessions.
final class SessionTests: XCTestCase {
  private static let sessionsScope = "io.opentelemetry.sessions"
  private static let sessionIdKey = "session.id"
  private static let previousSessionIdKey = "session.previous_id"
  private static let startEvent = "session.start"
  private static let endEvent = "session.end"

  private var sessionEvents: [ExportedLog] {
    OTLPOutput.logs
      .filter { $0.scope.name == Self.sessionsScope }
      .sorted { $0.record.timeUnixNano < $1.record.timeUnixNano }
  }

  private func sessionId(ofSpan name: String) throws -> String {
    try XCTUnwrap(OTLPOutput.spans.first { $0.span.name == name }?.span.attributes.string(Self.sessionIdKey),
                  "missing \(Self.sessionIdKey) on \(name)")
  }

  private func event(_ name: String, forSession id: String) -> ExportedLog? {
    sessionEvents.first {
      $0.record.eventName == name && $0.record.attributes.string(Self.sessionIdKey) == id
    }
  }

  func testSessionEventsAlternateStartAndEnd() {
    let names = sessionEvents.map(\.record.eventName)
    XCTAssertGreaterThanOrEqual(sessionEvents.count, 3, "expected at least start, end, start; got \(names)")
    XCTAssertEqual(names.first, Self.startEvent)
    XCTAssertEqual(names.last, Self.startEvent)
    for (index, name) in names.enumerated() {
      XCTAssertEqual(name, index.isMultiple(of: 2) ? Self.startEvent : Self.endEvent, "event \(index) in \(names)")
    }
    XCTAssertTrue(sessionEvents.allSatisfy { $0.record.timeUnixNano > 0 })
  }

  func testSessionChainIsLinkedThroughPreviousId() throws {
    let starts = sessionEvents.filter { $0.record.eventName == Self.startEvent }
    let ends = sessionEvents.filter { $0.record.eventName == Self.endEvent }

    let first = try XCTUnwrap(starts.first)
    XCTAssertEqual(first.record.attributes.string(Self.sessionIdKey), try sessionId(ofSpan: Scenario.rootSpanName))
    XCTAssertNil(first.record.attributes.string(Self.previousSessionIdKey), "the first session has no predecessor")

    for (previous, next) in zip(starts, starts.dropFirst()) {
      let previousId = try XCTUnwrap(previous.record.attributes.string(Self.sessionIdKey))
      XCTAssertEqual(next.record.attributes.string(Self.previousSessionIdKey), previousId)
    }

    XCTAssertEqual(ends.count, starts.count - 1, "every session but the last should have ended")
    for (start, end) in zip(starts, ends) {
      XCTAssertEqual(end.record.attributes.string(Self.sessionIdKey), start.record.attributes.string(Self.sessionIdKey))
      XCTAssertEqual(end.record.attributes.string(Self.previousSessionIdKey),
                     start.record.attributes.string(Self.previousSessionIdKey))
      XCTAssertGreaterThan(end.record.timeUnixNano, start.record.timeUnixNano)
    }
  }

  func testFirstSessionEndsBeforeTheSecondSessionSpan() throws {
    let firstSessionId = try sessionId(ofSpan: Scenario.rootSpanName)
    let secondSessionId = try sessionId(ofSpan: Scenario.secondSessionSpanName)
    XCTAssertNotEqual(firstSessionId, secondSessionId)

    let end = try XCTUnwrap(event(Self.endEvent, forSession: firstSessionId), "first session never ended")
    let secondStart = try XCTUnwrap(event(Self.startEvent, forSession: secondSessionId))
    XCTAssertLessThan(end.record.timeUnixNano, secondStart.record.timeUnixNano)
    XCTAssertNotNil(secondStart.record.attributes.string(Self.previousSessionIdKey))
  }

  func testSpansAreAttributedToTheRightSession() throws {
    let firstSessionId = try sessionId(ofSpan: Scenario.rootSpanName)
    let secondSessionId = try sessionId(ofSpan: Scenario.secondSessionSpanName)

    for name in [Scenario.rootSpanName, Scenario.childSpanName] {
      XCTAssertEqual(try sessionId(ofSpan: name), firstSessionId, name)
    }
    for code in Scenario.statusCodes {
      let span = OTLPOutput.spans.first { $0.span.attributes.string("http.target") == "/status/\(code)" }
      XCTAssertEqual(span?.span.attributes.string(Self.sessionIdKey), firstSessionId, "/status/\(code)")
    }
    XCTAssertEqual(try sessionId(ofSpan: Scenario.completionSpanName), secondSessionId,
                   "the completion marker is emitted right after the second-session span")

    let unattributed = OTLPOutput.spans.filter { $0.span.attributes.string(Self.sessionIdKey) == nil }
    XCTAssertTrue(unattributed.isEmpty, "every span should carry \(Self.sessionIdKey): \(unattributed.map(\.span.name))")
  }

  func testLogsCarryTheirSessionId() throws {
    let firstSessionId = try sessionId(ofSpan: Scenario.rootSpanName)
    let scenarioLog = try XCTUnwrap(OTLPOutput.logs.first { $0.scope.name == Scenario.scope })
    XCTAssertEqual(scenarioLog.record.attributes.string(Self.sessionIdKey), firstSessionId)

    let unattributed = OTLPOutput.logs.filter { $0.record.attributes.string(Self.sessionIdKey) == nil }
    XCTAssertTrue(unattributed.isEmpty, "every log should carry \(Self.sessionIdKey)")
  }
}

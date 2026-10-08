/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

// The crash launch records its session in a probe span and then crashes. The
// crash-report launch runs in a new session and reports the stored crash, which
// must carry the session context from when the crash happened rather than the
// session that is current when it is reported.
final class CrashTests: XCTestCase {
  private static let crashScope = "io.opentelemetry.kscrash"
  private static let crashEventName = "device.crash"
  private static let sessionIdKey = "session.id"
  private static let previousSessionIdKey = "session.previous_id"
  private static let exceptionTypeKey = "exception.type"
  private static let exceptionMessageKey = "exception.message"
  private static let exceptionStacktraceKey = "exception.stacktrace"

  private func crashLogs(_ launch: Scenario.Launch) -> [ExportedLog] {
    OTLPOutput.launch(launch).logs.filter {
      $0.scope.name == Self.crashScope && $0.record.eventName == Self.crashEventName
    }
  }

  private func probe(_ launch: Scenario.Launch) throws -> ExportedSpan {
    try XCTUnwrap(OTLPOutput.launch(launch).spans.first {
      $0.span.name == Scenario.probeSpanName && $0.span.attributes.string(Scenario.launchAttributeKey) == launch.rawValue
    }, "no probe span from the \(launch.rawValue) launch")
  }

  private func reportedCrash() throws -> ExportedLog {
    let logs = crashLogs(.crashReport)
    XCTAssertEqual(logs.count, 1, "expected exactly one crash reported on the launch after the crash")
    return try XCTUnwrap(logs.first)
  }

  func testCrashIsReportedOnTheNextLaunch() throws {
    XCTAssertTrue(crashLogs(.crash).isEmpty, "the crashing launch cannot report its own crash")

    let crash = try reportedCrash()
    XCTAssertEqual(crash.record.attributes.string(Self.exceptionTypeKey), "crash")
    XCTAssertFalse(crash.record.attributes.string(Self.exceptionMessageKey)?.isEmpty ?? true, "missing \(Self.exceptionMessageKey)")
    XCTAssertFalse(crash.record.attributes.string(Self.exceptionStacktraceKey)?.isEmpty ?? true, "missing \(Self.exceptionStacktraceKey)")
  }

  func testCrashKeepsTheCrashedSessionId() throws {
    let crashedSession = try XCTUnwrap(probe(.crash).span.attributes.string(Self.sessionIdKey))
    let reportingSession = try XCTUnwrap(probe(.crashReport).span.attributes.string(Self.sessionIdKey))
    XCTAssertNotEqual(crashedSession, reportingSession, "the crash must be reported from a different session to prove its context was kept")

    let crash = try reportedCrash()
    XCTAssertEqual(crash.record.attributes.string(Self.sessionIdKey), crashedSession,
                   "the crash must carry the session it happened in, not the session that reported it")
  }

  func testCrashKeepsTheCrashedSessionPreviousId() throws {
    let crashedPreviousSession = try XCTUnwrap(probe(.crash).span.attributes.string(Self.previousSessionIdKey),
                                               "the crash launch starts a fresh session linked to the previous launch's")

    let crash = try reportedCrash()
    XCTAssertEqual(crash.record.attributes.string(Self.previousSessionIdKey), crashedPreviousSession)
  }

  func testCrashIsTimestampedWhenItHappened() throws {
    let crashedAfter = try probe(.crash).span.startTimeUnixNano
    let reportedAfter = try probe(.crashReport).span.startTimeUnixNano

    let crash = try reportedCrash()
    XCTAssertGreaterThan(crash.record.timeUnixNano, crashedAfter, "the crash happened after the crash launch's probe span")
    XCTAssertLessThan(crash.record.timeUnixNano, reportedAfter, "the crash must keep its own time, not the time it was reported")
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

// Covers the SessionConfig options that only take effect when a SessionManager
// is created: maxLifetime and restorePersistedSession. The runner launches the
// app once per case (see IntegrationTestScenario.Launch) and each launch's
// telemetry lands in its own directory. The main launch covers sessionTimeout.
final class SessionConfigTests: XCTestCase {
  private static let sessionsScope = "io.opentelemetry.sessions"
  private static let sessionIdKey = "session.id"
  private static let previousSessionIdKey = "session.previous_id"
  private static let startEvent = "session.start"
  private static let endEvent = "session.end"

  private func sessionEvents(_ launch: Scenario.Launch) -> [ExportedLog] {
    OTLPOutput.launch(launch).logs
      .filter { $0.scope.name == Self.sessionsScope }
      .sorted { $0.record.timeUnixNano < $1.record.timeUnixNano }
  }

  private func scenarioSpans(_ launch: Scenario.Launch, named name: String) -> [ExportedSpan] {
    OTLPOutput.launch(launch).spans
      .filter { $0.span.name == name && $0.span.attributes.string(Scenario.launchAttributeKey) == launch.rawValue }
      .sorted { $0.span.startTimeUnixNano < $1.span.startTimeUnixNano }
  }

  private func sessionId(_ exported: ExportedSpan) throws -> String {
    try XCTUnwrap(exported.span.attributes.string(Self.sessionIdKey), "missing \(Self.sessionIdKey) on \(exported.span.name)")
  }

  private func seconds(from start: UInt64, to end: UInt64) -> Double {
    Double(end) / 1_000_000_000 - Double(start) / 1_000_000_000
  }

  // MARK: maxLifetime

  func testMaxLifetimeRollsTheSessionOverDespiteContinuousActivity() throws {
    let heartbeats = scenarioSpans(.maxLifetime, named: Scenario.heartbeatSpanName)
    XCTAssertGreaterThanOrEqual(heartbeats.count, 10, "expected the heartbeat spans from the max-lifetime launch")

    let sessionIds = try heartbeats.map(sessionId)
    let distinct = Array(NSOrderedSet(array: sessionIds)) as? [String] ?? []
    XCTAssertGreaterThanOrEqual(distinct.count, 2, "the session never rolled over: \(distinct)")

    // Heartbeats are 0.5s apart, so every session id must span less than maxLifetime + one interval.
    for id in distinct {
      let spans = heartbeats.filter { $0.span.attributes.string(Self.sessionIdKey) == id }
      let first = try XCTUnwrap(spans.first).span.startTimeUnixNano
      let last = try XCTUnwrap(spans.last).span.startTimeUnixNano
      XCTAssertLessThan(seconds(from: first, to: last), Scenario.maxLifetimeSeconds + 0.5, "session \(id) outlived maxLifetime")
    }
  }

  func testMaxLifetimeEmitsEndAndLinkedStartEvents() throws {
    let heartbeats = scenarioSpans(.maxLifetime, named: Scenario.heartbeatSpanName)
    let first = try sessionId(try XCTUnwrap(heartbeats.first))
    let last = try sessionId(try XCTUnwrap(heartbeats.last))
    XCTAssertNotEqual(first, last)

    let events = sessionEvents(.maxLifetime)
    let end = try XCTUnwrap(events.first {
      $0.record.eventName == Self.endEvent && $0.record.attributes.string(Self.sessionIdKey) == first
    }, "no session.end for the first heartbeat session")
    let start = try XCTUnwrap(events.first {
      $0.record.eventName == Self.startEvent && $0.record.attributes.string(Self.sessionIdKey) == first
    })
    let lifetime = seconds(from: start.record.timeUnixNano, to: end.record.timeUnixNano)
    XCTAssertEqual(lifetime, Scenario.maxLifetimeSeconds, accuracy: 1, "session.end should be stamped at start + maxLifetime")

    let successor = try XCTUnwrap(events.first {
      $0.record.eventName == Self.startEvent && $0.record.attributes.string(Self.previousSessionIdKey) == first
    }, "no session.start linked to the first heartbeat session")
    XCTAssertNotEqual(successor.record.attributes.string(Self.sessionIdKey), first)
  }

  // MARK: restorePersistedSession = true

  func testRestoredSessionKeepsItsIdAcrossLaunches() throws {
    let first = try sessionId(try XCTUnwrap(scenarioSpans(.restoreFirst, named: Scenario.probeSpanName).first))
    let second = try sessionId(try XCTUnwrap(scenarioSpans(.restoreSecond, named: Scenario.probeSpanName).first))
    XCTAssertEqual(first, second, "the second launch should resume the persisted session")

    let completion = try XCTUnwrap(scenarioSpans(.restoreSecond, named: Scenario.completionSpanName).first)
    XCTAssertEqual(try sessionId(completion), first)
  }

  func testRestoredSessionDoesNotEmitNewSessionEvents() throws {
    let restored = try sessionId(try XCTUnwrap(scenarioSpans(.restoreFirst, named: Scenario.probeSpanName).first))
    let events = sessionEvents(.restoreSecond)
    XCTAssertTrue(events.isEmpty, "resuming a session should not emit session events, got \(events.map(\.record.eventName))")

    let firstLaunchStarts = sessionEvents(.restoreFirst).filter {
      $0.record.eventName == Self.startEvent && $0.record.attributes.string(Self.sessionIdKey) == restored
    }
    XCTAssertEqual(firstLaunchStarts.count, 1, "the restored session should have started exactly once")
  }

  // MARK: restorePersistedSession = false

  func testDisablingRestoreStartsANewSessionLinkedToThePersistedOne() throws {
    let persisted = try sessionId(try XCTUnwrap(scenarioSpans(.restoreSecond, named: Scenario.probeSpanName).first))
    let fresh = try sessionId(try XCTUnwrap(scenarioSpans(.noRestore, named: Scenario.probeSpanName).first))
    XCTAssertNotEqual(fresh, persisted, "restorePersistedSession = false must start a new session")

    let events = sessionEvents(.noRestore)
    let end = try XCTUnwrap(events.first {
      $0.record.eventName == Self.endEvent && $0.record.attributes.string(Self.sessionIdKey) == persisted
    }, "the persisted session should be ended")
    let start = try XCTUnwrap(events.first {
      $0.record.eventName == Self.startEvent && $0.record.attributes.string(Self.sessionIdKey) == fresh
    })
    XCTAssertEqual(start.record.attributes.string(Self.previousSessionIdKey), persisted)
    XCTAssertLessThanOrEqual(end.record.timeUnixNano, start.record.timeUnixNano)
  }

  func testEveryLaunchTagsItsSpans() {
    for launch in [Scenario.Launch.maxLifetime, .restoreFirst, .restoreSecond, .noRestore] {
      let completion = scenarioSpans(launch, named: Scenario.completionSpanName)
      XCTAssertEqual(completion.count, 1, "launch \(launch.rawValue) should emit exactly one completion marker")
    }
  }
}

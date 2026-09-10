/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

// Names mirror IntegrationTestScenario in Examples/HackerNewsDemo.
enum Scenario {
  static let scope = "HackerNewsDemo.IntegrationTest"
  static let rootSpanName = "integration.test.root"
  static let childSpanName = "integration.test.child"
  static let completionSpanName = "integration.test.complete"
  static let logBody = "integration test log"
  static let logEventName = "integration.test.event"
  static let attributeKey = "integration.test.attribute"
  static let attributeValue = "hello"
  static let statusCodes: [Int64] = [200, 404, 500]
  static let secondSessionSpanName = "integration.test.second-session"
  static let heartbeatSpanName = "integration.test.heartbeat"
  static let probeSpanName = "integration.test.probe"
  static let launchAttributeKey = "integration.test.launch"

  // One entry per app launch made by Scripts/run-integration-tests.sh.
  enum Launch: String {
    case main
    case maxLifetime = "max-lifetime"
    case restoreFirst = "restore-first"
    case restoreSecond = "restore-second"
    case noRestore = "no-restore"
  }

  // Session config the runner passes to each launch.
  static let maxLifetimeSeconds: TimeInterval = 3
}

final class CustomTelemetryTests: XCTestCase {
  private var scenarioSpans: [ExportedSpan] {
    OTLPOutput.spans.filter { $0.scope.name == Scenario.scope }
  }

  func testRootSpanIsExportedWithAttributes() throws {
    let root = try XCTUnwrap(scenarioSpans.first { $0.span.name == Scenario.rootSpanName })
    XCTAssertEqual(root.span.kind, .client)
    XCTAssertEqual(root.span.attributes.string(Scenario.attributeKey), Scenario.attributeValue)
    XCTAssertTrue(root.span.parentSpanID.isEmpty)
    XCTAssertGreaterThan(root.span.startTimeUnixNano, 0)
    XCTAssertGreaterThanOrEqual(root.span.endTimeUnixNano, root.span.startTimeUnixNano)
  }

  func testChildSpanIsLinkedToRoot() throws {
    let root = try XCTUnwrap(scenarioSpans.first { $0.span.name == Scenario.rootSpanName })
    let child = try XCTUnwrap(scenarioSpans.first { $0.span.name == Scenario.childSpanName })
    XCTAssertEqual(child.span.traceID, root.span.traceID)
    XCTAssertEqual(child.span.parentSpanID, root.span.spanID)
    XCTAssertEqual(child.span.kind, .internal)
    XCTAssertEqual(child.span.events.map(\.name), ["child.event"])
  }

  func testCompletionMarkerIsExportedOnce() {
    XCTAssertEqual(scenarioSpans.filter { $0.span.name == Scenario.completionSpanName }.count, 1)
  }

  func testLogRecordIsExported() throws {
    let log = try XCTUnwrap(OTLPOutput.logs.first { $0.scope.name == Scenario.scope })
    XCTAssertEqual(log.record.body.stringValue, Scenario.logBody)
    XCTAssertEqual(log.record.eventName, Scenario.logEventName)
    XCTAssertEqual(log.record.severityText, "INFO")
    XCTAssertEqual(log.record.severityNumber, .info)
    XCTAssertEqual(log.record.attributes.string(Scenario.attributeKey), Scenario.attributeValue)
    XCTAssertGreaterThan(log.record.timeUnixNano, 0)
  }
}

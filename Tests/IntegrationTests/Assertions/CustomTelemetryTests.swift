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
  static let statusCodes = [200, 404, 500]
  static let secondSessionSpanName = "integration.test.second-session"
}

final class CustomTelemetryTests: XCTestCase {
  private var scenarioSpans: [ExportedSpan] {
    OTLPOutput.spans.filter { $0.scope.name == Scenario.scope }
  }

  func testRootSpanIsExportedWithAttributes() throws {
    let root = try XCTUnwrap(scenarioSpans.first { $0.span.name == Scenario.rootSpanName })
    XCTAssertEqual(root.span.kind, "SPAN_KIND_CLIENT")
    XCTAssertEqual(root.span.attributes?.string(Scenario.attributeKey), Scenario.attributeValue)
    XCTAssertNil(root.span.parentSpanId)
    XCTAssertNotNil(root.span.startTimeUnixNano)
    XCTAssertNotNil(root.span.endTimeUnixNano)
  }

  func testChildSpanIsLinkedToRoot() throws {
    let root = try XCTUnwrap(scenarioSpans.first { $0.span.name == Scenario.rootSpanName })
    let child = try XCTUnwrap(scenarioSpans.first { $0.span.name == Scenario.childSpanName })
    XCTAssertEqual(child.span.traceId, root.span.traceId)
    XCTAssertEqual(child.span.parentSpanId, root.span.spanId)
    XCTAssertEqual(child.span.kind, "SPAN_KIND_INTERNAL")
    XCTAssertEqual(child.span.events?.map(\.name), ["child.event"])
  }

  func testCompletionMarkerIsExportedOnce() {
    XCTAssertEqual(scenarioSpans.filter { $0.span.name == Scenario.completionSpanName }.count, 1)
  }

  func testLogRecordIsExported() throws {
    let log = try XCTUnwrap(OTLPOutput.logs.first { $0.scope.name == Scenario.scope })
    XCTAssertEqual(log.record.body?.stringValue, Scenario.logBody)
    XCTAssertEqual(log.record.eventName, Scenario.logEventName)
    XCTAssertEqual(log.record.severityText, "INFO")
    XCTAssertEqual(log.record.severityNumber, "SEVERITY_NUMBER_INFO")
    XCTAssertEqual(log.record.attributes?.string(Scenario.attributeKey), Scenario.attributeValue)
    XCTAssertNotNil(log.record.timeUnixNano)
  }
}

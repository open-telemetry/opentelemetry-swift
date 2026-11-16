/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

final class SessionSamplingTests: XCTestCase {
  private static let scope = "HackerNewsDemo.IntegrationTest.LogLimits"
  private static let decisionKey = "session.sampling_decision"
  private static let sessionCreatedKey = "integration.test.session-created"

  func testAttributeLimitedLogsKeepHistoricalDecisions() {
    let logs = OTLPOutput.launch(.logLimits).logs.filter { $0.scope.name == Self.scope }
    let historical = logs.filter(\.record.eventName.isEmpty)
    XCTAssertEqual(historical.map(\.record.body.stringValue).sorted(), ["invalid", "sampled"])
    for log in historical {
      XCTAssertEqual(log.record.attributes.count, 1)
      XCTAssertEqual(log.record.attributes.string(Self.decisionKey), log.record.body.stringValue)
    }
    let lifecycle = logs.filter { !$0.record.eventName.isEmpty }
    XCTAssertEqual(lifecycle.map(\.record.eventName).sorted(), ["session.end", "session.start"])
    XCTAssertTrue(lifecycle.allSatisfy(\.record.attributes.isEmpty))
  }

  func testStrippedLifecycleEventsDoNotStartSession() throws {
    let probes = OTLPOutput.launch(.logLimits).spans.filter { $0.span.name == Scenario.probeSpanName }
    XCTAssertEqual(probes.count, 1)
    let attribute = try XCTUnwrap(probes.first?.span.attributes[Self.sessionCreatedKey])
    XCTAssertEqual(attribute.value, .boolValue(false))
  }
}

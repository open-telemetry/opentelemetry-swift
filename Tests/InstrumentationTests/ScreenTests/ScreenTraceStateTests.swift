/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(SwiftUI)
  import InstrumentationSemanticConventions
import OpenTelemetryApi
  @testable import OpenTelemetrySdk
  @testable import ScreenInstrumentation
@testable import ScreenInstrumentationSwiftUI
  import XCTest

  /// Covers what the SwiftUI modifier does when a view appears. The reporting lives on
  /// `ScreenTraceState` so these run without rendering a view hierarchy.
  final class ScreenTraceStateTests: XCTestCase {
    private var tracker: ScreenTracker!
    private var logs: RecordingLogRecordProcessor!
    private var spans: RecordingSpanProcessor!

    override func setUp() {
      super.setUp()
      let providers = ScreenTestFixtures.registerRecordingProviders()
      spans = providers.spans
      logs = providers.logs
      tracker = ScreenTracker()
    }

    func testFirstAppearanceReportsTheScreenAndItsTiming() {
      let loaded = Date(timeIntervalSince1970: 1_700_000_000)
      let state = ScreenTraceState(loadTime: loaded)

      state.reportAppearance(screen: "Settings",
                             attributes: [:],
                             now: loaded.addingTimeInterval(0.1),
                             screenTracker: tracker)

      XCTAssertEqual(tracker.currentScreen, "Settings")
      XCTAssertEqual(navigationEvents().count, 1)

      let span = timeToFirstAppearSpans().first
      guard let span else { return XCTFail("expected a time_to_first_appear span") }
      XCTAssertEqual(span.startTime, loaded)
      XCTAssertEqual(span.endTime, loaded.addingTimeInterval(0.1))
      XCTAssertEqual(ScreenTestFixtures.string(span.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "swiftui")
    }

    func testSecondAppearanceReportsNoSecondSpan() {
      let state = ScreenTraceState()

      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker)
      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker)

      XCTAssertEqual(timeToFirstAppearSpans().count, 1)
    }

    func testComingBackToAScreenReportsTheNavigationAgain() {
      let settings = ScreenTraceState()
      settings.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker)
      tracker.setCurrent(screen: "Stories", type: .uikit)
      settings.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker)

      XCTAssertEqual(navigationEvents().count, 3)
      XCTAssertEqual(timeToFirstAppearSpans().count, 1)
    }

    func testAttributesReachBothSignals() {
      let state = ScreenTraceState()

      state.reportAppearance(screen: "Settings",
                             attributes: ["tab": .string("settings")],
                             screenTracker: tracker)

      XCTAssertEqual(ScreenTestFixtures.string(navigationEvents().first?.attributes["tab"]), "settings")
      XCTAssertEqual(ScreenTestFixtures.string(timeToFirstAppearSpans().first?.attributes["tab"]), "settings")
    }

    private func navigationEvents() -> [ReadableLogRecord] {
      logs.records.filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
    }

    private func timeToFirstAppearSpans() -> [SpanData] {
      spans.spans.filter { $0.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstAppear.rawValue }
    }
  }
#endif

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
  import InstrumentationCommon
  import XCTest

  /// Covers what the SwiftUI modifier does when a view appears. The reporting lives on
  /// `ScreenTraceState` so these run without rendering a view hierarchy.
  final class ScreenTraceStateTests: XCTestCase {
    private var tracker: ScreenTracker!
    private var logs: RecordingLogRecordProcessor!
    private var spans: RecordingSpanProcessor!
    private var frames: FakeFirstFrameReader!

    override func setUp() {
      super.setUp()
      let providers = ScreenTestFixtures.registerRecordingProviders()
      spans = providers.spans
      logs = providers.logs
      tracker = ScreenTracker()
      frames = FakeFirstFrameReader()
    }

    func testFirstAppearanceReportsTheScreenAndItsFirstDraw() {
      let loaded = Date(timeIntervalSince1970: 1_700_000_000)
      let state = ScreenTraceState(loadTime: loaded)

      state.reportAppearance(screen: "Settings",
                             attributes: [:],
                             now: loaded.addingTimeInterval(0.1),
                             screenTracker: tracker,
                             firstFrameReader: frames)

      XCTAssertEqual(tracker.currentScreen, "Settings")
      XCTAssertEqual(navigationEvents().count, 1)
      XCTAssertTrue(timeToFirstDrawSpans().isEmpty, "the span waits for the frame")

      frames.fire(at: loaded.addingTimeInterval(0.13))

      let span = timeToFirstDrawSpans().first
      guard let span else { return XCTFail("expected a time_to_first_draw span") }
      XCTAssertEqual(span.startTime, loaded)
      XCTAssertEqual(span.endTime, loaded.addingTimeInterval(0.13))
      XCTAssertEqual(ScreenTestFixtures.string(span.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "swiftui")
    }

    func testSecondAppearanceReportsNoSecondSpan() {
      let state = ScreenTraceState()

      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      frames.fire(at: Date())
      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      frames.fire(at: Date())

      XCTAssertEqual(timeToFirstDrawSpans().count, 1)
    }

    func testComingBackToAScreenReportsTheNavigationAgain() {
      let settings = ScreenTraceState()
      settings.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      frames.fire(at: Date())
      tracker.setCurrent(screen: "Stories", type: .uikit)
      settings.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      frames.fire(at: Date())

      XCTAssertEqual(navigationEvents().count, 3)
      XCTAssertEqual(timeToFirstDrawSpans().count, 1)
    }

    func testAttributesReachBothSignals() {
      let state = ScreenTraceState()

      state.reportAppearance(screen: "Settings",
                             attributes: ["tab": .string("settings")],
                             screenTracker: tracker,
                             firstFrameReader: frames)
      frames.fire(at: Date())

      XCTAssertEqual(ScreenTestFixtures.string(navigationEvents().first?.attributes["tab"]), "settings")
      XCTAssertEqual(ScreenTestFixtures.string(timeToFirstDrawSpans().first?.attributes["tab"]), "settings")
    }

    func testWithoutAFrameReaderTheSpanEndsAtAppearance() {
      let loaded = Date(timeIntervalSince1970: 1_700_000_000)
      let state = ScreenTraceState(loadTime: loaded)

      state.reportAppearance(screen: "Settings",
                             attributes: [:],
                             now: loaded.addingTimeInterval(0.1),
                             screenTracker: tracker,
                             firstFrameReader: nil)

      XCTAssertEqual(timeToFirstDrawSpans().first?.endTime, loaded.addingTimeInterval(0.1))
    }

    func testCancellingAPendingDrawRecordsNoSpan() {
      let state = ScreenTraceState()

      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      state.cancelPendingDraw()
      frames.fire(at: Date())

      XCTAssertEqual(frames.cancelledCount, 1)
      XCTAssertTrue(timeToFirstDrawSpans().isEmpty)
      XCTAssertEqual(tracker.currentScreen, "Settings")
    }

    func testAScreenBackgroundedBeforeItsFirstDrawMeasuresOnItsNextAppearance() {
      let loaded = Date(timeIntervalSince1970: 1_700_000_000)
      let state = ScreenTraceState(loadTime: loaded)

      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      state.cancelPendingDraw()
      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      frames.fire(at: loaded.addingTimeInterval(5))

      XCTAssertEqual(timeToFirstDrawSpans().count, 1)
      XCTAssertEqual(timeToFirstDrawSpans().first?.startTime, loaded)
      XCTAssertEqual(timeToFirstDrawSpans().first?.endTime, loaded.addingTimeInterval(5))
    }

    func testBackgroundingAfterTheFirstDrawReportsNoSecondSpan() {
      let state = ScreenTraceState()

      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      frames.fire(at: Date())
      state.cancelPendingDraw()
      state.reportAppearance(screen: "Settings", attributes: [:], screenTracker: tracker, firstFrameReader: frames)
      frames.fire(at: Date())

      XCTAssertEqual(timeToFirstDrawSpans().count, 1)
    }

    private func navigationEvents() -> [ReadableLogRecord] {
      logs.records.filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
    }

    private func timeToFirstDrawSpans() -> [SpanData] {
      spans.spans.filter { $0.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue }
    }
  }
#endif

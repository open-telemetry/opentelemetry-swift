/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InstrumentationSemanticConventions
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import ScreenInstrumentation
import XCTest

final class ScreenTrackerTests: XCTestCase {
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

  // MARK: - Current and previous screen

  func testStartsWithNoScreen() {
    XCTAssertNil(tracker.currentScreen)
    XCTAssertNil(tracker.previousScreen)
  }

  func testRecordsTheTransition() {
    tracker.setCurrent(screen: "Stories", type: .uikit)
    XCTAssertEqual(tracker.currentScreen, "Stories")
    XCTAssertNil(tracker.previousScreen)

    tracker.setCurrent(screen: "Comments", type: .uikit)
    XCTAssertEqual(tracker.currentScreen, "Comments")
    XCTAssertEqual(tracker.previousScreen, "Stories")
  }

  func testGoingBackReportsTheScreenAgain() {
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Comments", type: .uikit)
    tracker.setCurrent(screen: "Stories", type: .uikit)

    XCTAssertEqual(tracker.currentScreen, "Stories")
    XCTAssertEqual(tracker.previousScreen, "Comments")
    XCTAssertEqual(navigationEvents().count, 3)
  }

  // MARK: - app.navigation.complete

  func testSetCurrentWithoutATypeReportsAManualScreen() {
    tracker.setCurrent(screen: "Checkout")

    XCTAssertEqual(tracker.currentScreen, "Checkout")
    let event = navigationEvents().first
    XCTAssertEqual(ScreenTestFixtures.string(event?.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "manual")
    XCTAssertEqual(ScreenTestFixtures.string(event?.attributes[FederatedSemanticConventions.App.navigationDestinationName.rawValue]),
                   "Checkout")
    XCTAssertEqual(event?.instrumentationScopeInfo.name, "io.opentelemetry.screen")
  }

  func testEachTypeEmitsUnderItsOwnScope() {
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Settings", type: .swiftui)
    tracker.setCurrent(screen: "Checkout", type: .manual)

    XCTAssertEqual(navigationEvents().map(\.instrumentationScopeInfo.name),
                   ["io.opentelemetry.screen.uikit", "io.opentelemetry.screen.swiftui", "io.opentelemetry.screen"])
  }

  func testManualTimeToFirstDrawUsesTheManualScope() {
    let loaded = Date()
    tracker.recordTimeToFirstDraw(screen: "Checkout",
                                  type: .manual,
                                  loadTime: loaded,
                                  drawTime: loaded.addingTimeInterval(0.1))

    let span = spans.spans.first { $0.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue }
    XCTAssertEqual(span?.instrumentationScope.name, "io.opentelemetry.screen")
    XCTAssertEqual(ScreenTestFixtures.string(span?.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "manual")
  }

  func testEmitsOneEventPerChange() {
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Comments", type: .uikit)

    XCTAssertEqual(navigationEvents().count, 2)
  }

  func testEventNamesTheDestination() {
    tracker.setCurrent(screen: "Stories", type: .uikit)

    let event = try? XCTUnwrap(navigationEvents().first)
    XCTAssertEqual(ScreenTestFixtures.string(event?.attributes[FederatedSemanticConventions.App.navigationDestinationName.rawValue]),
                   "Stories")
    XCTAssertEqual(ScreenTestFixtures.string(event?.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "uikit")
  }

  func testFirstScreenHasNoPreviousName() {
    tracker.setCurrent(screen: "Stories", type: .uikit)

    let event = navigationEvents().first
    XCTAssertNil(event?.attributes[FederatedSemanticConventions.App.screenPreviousName.rawValue])
  }

  func testLaterScreenNamesThePreviousOne() {
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Comments", type: .swiftui)

    let event = navigationEvents().last
    XCTAssertEqual(ScreenTestFixtures.string(event?.attributes[FederatedSemanticConventions.App.screenPreviousName.rawValue]),
                   "Stories")
    XCTAssertEqual(ScreenTestFixtures.string(event?.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "swiftui")
  }

  func testEventCarriesTheGivenTimestamp() {
    let appeared = Date(timeIntervalSince1970: 1_700_000_000)
    tracker.setCurrent(screen: "Stories", type: .uikit, timestamp: appeared)

    XCTAssertEqual(navigationEvents().first?.timestamp, appeared)
  }

  func testEventCarriesExtraAttributes() {
    tracker.setCurrent(screen: "Stories",
                       type: .uikit,
                       attributes: ["story.count": .int(30)])

    guard case let .int(count)? = navigationEvents().first?.attributes["story.count"] else {
      return XCTFail("expected story.count on the navigation event")
    }
    XCTAssertEqual(count, 30)
  }

  func testPostsAScreenChangeNotification() {
    let received = expectation(description: "screen change")
    let observer = NotificationCenter.default.addObserver(forName: ScreenChangeNotification,
                                                          object: nil,
                                                          queue: nil) { notification in
      XCTAssertEqual(notification.object as? String, "Stories")
      received.fulfill()
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    tracker.setCurrent(screen: "Stories", type: .uikit)
    wait(for: [received], timeout: 1)
  }

  // MARK: - app.screen.time_to_first_draw

  func testRecordsTimeToFirstDraw() {
    let loaded = Date(timeIntervalSince1970: 1_700_000_000)
    let drawn = loaded.addingTimeInterval(0.25)

    tracker.recordTimeToFirstDraw(screen: "Stories",
                                  type: .uikit,
                                  loadTime: loaded,
                                  drawTime: drawn)

    let span = spans.spans.first { $0.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue }
    guard let span else { return XCTFail("expected a time_to_first_draw span") }
    XCTAssertEqual(span.startTime, loaded)
    XCTAssertEqual(span.endTime, drawn)
    XCTAssertEqual(ScreenTestFixtures.string(span.attributes[SemanticConventions.App.screenName.rawValue]),
                   "Stories")
    XCTAssertEqual(ScreenTestFixtures.string(span.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "uikit")
  }

  func testTimeToFirstDrawCarriesExtraAttributes() {
    let loaded = Date()
    tracker.recordTimeToFirstDraw(screen: "Settings",
                                  type: .swiftui,
                                  loadTime: loaded,
                                  drawTime: loaded.addingTimeInterval(0.01),
                                  attributes: ["tab": .string("settings")])

    let span = spans.spans.first { $0.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue }
    XCTAssertEqual(ScreenTestFixtures.string(span?.attributes["tab"]), "settings")
  }

  // MARK: - Thread safety

  func testConcurrentChangesLeaveOneConsistentTransition() {
    let names = (0 ..< 200).map { "Screen\($0)" }
    let tracker = tracker!
    let group = DispatchGroup()
    for name in names {
      DispatchQueue.global().async(group: group) {
        tracker.setCurrent(screen: name, type: .uikit)
      }
    }
    group.wait()

    // Every change emits exactly one event, and no transition is lost or doubled.
    XCTAssertEqual(navigationEvents().count, names.count)
    XCTAssertNotNil(tracker.currentScreen)
    XCTAssertNotEqual(tracker.currentScreen, tracker.previousScreen)
  }

  private func navigationEvents() -> [ReadableLogRecord] {
    logs.records.filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
  }
}

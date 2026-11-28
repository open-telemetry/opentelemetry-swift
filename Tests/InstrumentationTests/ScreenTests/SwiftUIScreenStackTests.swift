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

  /// Drives the stack with the callback orders a Revyl simulator showed for each SwiftUI
  /// navigation, with a scheduler the test runs by hand.
  final class SwiftUIScreenStackTests: XCTestCase {
    private var tracker: ScreenTracker!
    private var logs: RecordingLogRecordProcessor!
    private var scheduled: [() -> Void] = []
    private var stack: SwiftUIScreenStack!

    override func setUp() {
      super.setUp()
      logs = ScreenTestFixtures.registerRecordingProviders().logs
      tracker = ScreenTracker()
      scheduled = []
      stack = SwiftUIScreenStack { [unowned self] _, block in scheduled.append(block) }
    }

    func testTheFirstScreenIsInitialAndANewOneIsAPush() {
      let home = ScreenTraceState()
      let detail = ScreenTraceState()

      appear(home, "Home")
      appear(detail, "Detail")

      XCTAssertEqual(events(), [Event("Home", "initial"), Event("Detail", "push")])
    }

    func testAPopWaitsForTheRemovedScreen() {
      let home = ScreenTraceState()
      var detail: ScreenTraceState? = ScreenTraceState()
      appear(home, "Home")
      appear(detail!, "Detail")

      // The revealed screen appears about half a second before the removed one disappears.
      appear(home, "Home")
      XCTAssertEqual(tracker.currentScreen, "Detail")

      stack.disappear(detail!, now: Date(), tracker: tracker)
      detail = nil
      runScheduled()

      XCTAssertEqual(events().last, Event("Home", "pop"))
      XCTAssertEqual(tracker.currentScreen, "Home")
    }

    func testRemovingSeveralScreensIsAPopTo() {
      let root = ScreenTraceState()
      var first: ScreenTraceState? = ScreenTraceState()
      var second: ScreenTraceState? = ScreenTraceState()
      appear(root, "Root")
      appear(first!, "First")
      appear(second!, "Second")

      // The screens in between are freed with no onDisappear.
      first = nil
      appear(root, "Root")
      stack.disappear(second!, now: Date(), tracker: tracker)
      second = nil
      runScheduled()

      XCTAssertEqual(events().last, Event("Root", "pop_to"))
    }

    func testADismissedSheetMakesItsPresenterCurrentAgain() {
      let settings = ScreenTraceState()
      var sheet: ScreenTraceState? = ScreenTraceState()
      appear(settings, "Settings")
      appear(sheet!, "Session Config")

      // The presenter gets neither onDisappear nor onAppear.
      stack.disappear(sheet!, now: Date(), tracker: tracker)
      sheet = nil
      runScheduled()

      XCTAssertEqual(events().last, Event("Settings", "pop"))
      XCTAssertEqual(tracker.currentScreen, "Settings")
    }

    func testAnExpectedTypeLabelsTheChange() {
      let settings = ScreenTraceState()
      var sheet: ScreenTraceState? = ScreenTraceState()
      appear(settings, "Settings")
      stack.expect(.modal)
      appear(sheet!, "Session Config")

      stack.expect(.dismiss)
      stack.disappear(sheet!, now: Date(), tracker: tracker)
      sheet = nil
      runScheduled()

      XCTAssertEqual(events(), [Event("Settings", "initial"), Event("Session Config", "modal"), Event("Settings", "dismiss")])
    }

    func testAnExpectationExpires() {
      let home = ScreenTraceState()
      let detail = ScreenTraceState()
      appear(home, "Home")
      stack.expect(.modal, now: Date().addingTimeInterval(-SwiftUIScreenStack.expectationLifetime - 1))
      appear(detail, "Detail")

      XCTAssertEqual(events().last, Event("Detail", "push"))
    }

    func testATabSwitchBackRemovesNothing() {
      let first = ScreenTraceState()
      let second = ScreenTraceState()
      appear(first, "First")
      appear(second, "Second")

      // A TabView keeps both tabs' state.
      appear(first, "First")
      stack.disappear(second, now: Date(), tracker: tracker)
      runScheduled()

      XCTAssertEqual(events().last, Event("First", nil))
    }

    func testACancelledInteractivePopReportsNothing() {
      let home = ScreenTraceState()
      let detail = ScreenTraceState()
      appear(home, "Home")
      appear(detail, "Detail")

      // The revealed screen appears as the drag starts and disappears again when it is cancelled.
      appear(home, "Home")
      stack.disappear(home, now: Date(), tracker: tracker)
      runScheduled()

      XCTAssertEqual(events().count, 2)
      XCTAssertEqual(tracker.currentScreen, "Detail")
    }

    func testAScreenRevealedAfterAnotherFrontEndTookOverReportsAtOnce() {
      let settings = ScreenTraceState()
      appear(settings, "Settings")
      tracker.setCurrent(screen: "StoriesViewController", type: .uikit)

      appear(settings, "Settings")

      XCTAssertEqual(events().last, Event("Settings", nil))
      XCTAssertTrue(scheduled.isEmpty)
    }

    func testTurningNavigationOffReportsEveryAppearanceAndNoDisappearance() {
      tracker = ScreenTracker(tracksNavigation: false)
      let settings = ScreenTraceState()
      var sheet: ScreenTraceState? = ScreenTraceState()
      appear(settings, "Settings")
      appear(sheet!, "Session Config")

      stack.disappear(sheet!, now: Date(), tracker: tracker)
      sheet = nil
      runScheduled()

      XCTAssertEqual(events(), [Event("Settings", nil), Event("Session Config", nil)])
      XCTAssertEqual(tracker.currentScreen, "Session Config")
    }

    func testRemovalCountsClassifyTheChange() {
      XCTAssertNil(SwiftUIScreenStack.navigation(removing: 0))
      XCTAssertEqual(SwiftUIScreenStack.navigation(removing: 1), .pop)
      XCTAssertEqual(SwiftUIScreenStack.navigation(removing: 2), .popTo)
    }

    // MARK: - Opt-in bindings

    func testAPathChangeClassifiesTheNavigation() {
      XCTAssertEqual(SwiftUIScreenStack.navigation(from: [1], to: [1, 2]), .push)
      XCTAssertEqual(SwiftUIScreenStack.navigation(from: [1, 2], to: [1]), .pop)
      XCTAssertEqual(SwiftUIScreenStack.navigation(from: [1, 2, 3], to: [1]), .popTo)
      XCTAssertEqual(SwiftUIScreenStack.navigation(from: [1, 2, 3], to: []), .popTo)
      XCTAssertEqual(SwiftUIScreenStack.navigation(from: [1, 2], to: [1, 3]), .replace)
      XCTAssertEqual(SwiftUIScreenStack.navigation(from: [1, 2], to: [4]), .reset)
      XCTAssertNil(SwiftUIScreenStack.navigation(from: [1, 2], to: [1, 2]))
    }

    func testAPathObserverLabelsTheNextScreen() {
      let observer = NavigationChangeObserver(initial: [1, 2], stack: stack, classify: SwiftUIScreenStack.navigation(from:to:))
      let home = ScreenTraceState()
      let detail = ScreenTraceState()
      appear(home, "Home")

      observer.observe([9])
      appear(detail, "Detail")

      XCTAssertEqual(events().last, Event("Detail", "reset"))
    }

    func testATabObserverLabelsASwitchAndIgnoresTheSameTab() {
      let observer = NavigationChangeObserver(initial: 0, stack: stack, classify: SwiftUIScreenStack.navigation(selecting:to:))
      let first = ScreenTraceState()
      let second = ScreenTraceState()
      let third = ScreenTraceState()
      appear(first, "First")

      observer.observe(1)
      appear(second, "Second")
      observer.observe(1)
      appear(third, "Third")

      XCTAssertEqual(events().suffix(2), [Event("Second", "switch"), Event("Third", "push")])
    }

    func testAModalObserverLabelsPresentAndDismiss() {
      let observer = NavigationChangeObserver(initial: false, stack: stack, classify: SwiftUIScreenStack.navigation(presenting:to:))
      let settings = ScreenTraceState()
      var sheet: ScreenTraceState? = ScreenTraceState()
      appear(settings, "Settings")

      observer.observe(true)
      appear(sheet!, "Session Config")
      observer.observe(false)
      stack.disappear(sheet!, now: Date(), tracker: tracker)
      sheet = nil
      runScheduled()

      XCTAssertEqual(events().suffix(2), [Event("Session Config", "modal"), Event("Settings", "dismiss")])
    }

    func testPresentationAndSelectionChangesClassify() {
      XCTAssertEqual(SwiftUIScreenStack.navigation(presenting: false, to: true), .modal)
      XCTAssertEqual(SwiftUIScreenStack.navigation(presenting: true, to: false), .dismiss)
      XCTAssertNil(SwiftUIScreenStack.navigation(presenting: true, to: true))
      XCTAssertEqual(SwiftUIScreenStack.navigation(selecting: "a", to: "b"), .switch)
      XCTAssertNil(SwiftUIScreenStack.navigation(selecting: "a", to: "a"))
    }

    // MARK: - Helpers

    private struct Event: Equatable {
      let destination: String?
      let type: String?

      init(_ destination: String?, _ type: String?) {
        self.destination = destination
        self.type = type
      }
    }

    private func appear(_ state: ScreenTraceState, _ screen: String) {
      stack.appear(state, screen: screen, attributes: [:], now: Date(), tracker: tracker)
    }

    private func runScheduled() {
      let blocks = scheduled
      scheduled = []
      blocks.forEach { $0() }
    }

    private func events() -> [Event] {
      logs.records
        .filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
        .map {
          Event(ScreenTestFixtures.string($0.attributes[FederatedSemanticConventions.App.navigationDestinationName.rawValue]),
                ScreenTestFixtures.string($0.attributes[FederatedSemanticConventions.App.navigationType.rawValue]))
        }
    }
  }
#endif

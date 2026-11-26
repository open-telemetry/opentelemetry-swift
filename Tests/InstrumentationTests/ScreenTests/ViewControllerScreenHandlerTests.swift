/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(UIKit) && !os(watchOS)
  import InstrumentationSemanticConventions
import OpenTelemetryApi
  @testable import OpenTelemetrySdk
  @testable import ScreenInstrumentation
@testable import ScreenInstrumentationUIKit
  import UIKit
  import XCTest

  private final class StoriesViewController: UIViewController {}

  private final class NamedViewController: UIViewController, ScreenTrackingCustomization {
    var customScreenName: String? { "Login" }
  }

  private final class SilentViewController: UIViewController, ScreenTrackingCustomization {
    var tracksScreen: Bool { false }
  }

  private final class DemoHostingController: UIHostingControllerStub {}

  /// Stands in for `UIHostingController`, which cannot be subclassed here without SwiftUI
  /// content. The handler recognises a hosting controller by the class name, so a class with
  /// that name exercises the same branch.
  private class UIHostingControllerStub: UIViewController {}

  final class ViewControllerScreenHandlerTests: XCTestCase {
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

    /// The test bundle, not the app bundle: that is where these view controllers live.
    @MainActor
    private func makeHandler(_ config: ScreenUIKitConfig? = nil) -> ViewControllerScreenHandler {
      ViewControllerScreenHandler(
        config: config ?? ScreenUIKitConfig(bundle: Bundle(for: ViewControllerScreenHandlerTests.self)),
        screenTracker: tracker
      )
    }

    // MARK: - Naming

    @MainActor
    func testUsesTheClassName() {
      let handler = makeHandler()
      XCTAssertEqual(handler.screenName(StoriesViewController()), "StoriesViewController")
    }

    @MainActor
    func testUsesACustomName() {
      let handler = makeHandler()
      XCTAssertEqual(handler.screenName(NamedViewController()), "Login")
    }

    @MainActor
    func testDropsTheModulePrefixAndGenericArguments() {
      XCTAssertEqual(ViewControllerScreenHandler.screenName(for: UIViewController.self), "UIViewController")
      XCTAssertEqual(ViewControllerScreenHandler.screenName(for: StoriesViewController.self),
                     "StoriesViewController")
    }

    // MARK: - What to track

    @MainActor
    func testTracksAViewControllerFromTheConfiguredBundle() {
      let handler = makeHandler()
      XCTAssertTrue(handler.tracksScreen(StoriesViewController()))
    }

    @MainActor
    func testSkipsAFrameworkViewController() {
      let handler = makeHandler()
      XCTAssertFalse(handler.tracksScreen(UINavigationController()))
    }

    @MainActor
    func testSkipsAViewControllerThatOptsOut() {
      let handler = makeHandler()
      XCTAssertFalse(handler.tracksScreen(SilentViewController()))
    }

    @MainActor
    func testSkipsAHostingControllerByDefault() {
      let handler = makeHandler()
      XCTAssertFalse(handler.tracksScreen(DemoHostingController()))
    }

    @MainActor
    func testTracksAHostingControllerWhenConfiguredTo() {
      let handler = makeHandler(ScreenUIKitConfig(
        bundle: Bundle(for: ViewControllerScreenHandlerTests.self),
        tracksHostingControllers: true
      ))

      XCTAssertTrue(handler.tracksScreen(DemoHostingController()))
    }

    // MARK: - Lifecycle

    @MainActor
    func testLoadingDoesNotChangeTheCurrentScreen() {
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController)

      XCTAssertNil(tracker.currentScreen)
      XCTAssertNotNil(viewController.screenTrackingState)
    }

    @MainActor
    func testAppearingReportsTheScreenAndItsTiming() {
      let handler = makeHandler()
      let loaded = Date(timeIntervalSince1970: 1_700_000_000)
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController, now: loaded)
      handler.onViewDidAppear(viewController, now: loaded.addingTimeInterval(0.2))

      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
      XCTAssertEqual(navigationEvents().count, 1)

      let span = timeToFirstAppearSpans().first
      guard let span else { return XCTFail("expected a time_to_first_appear span") }
      XCTAssertEqual(span.startTime, loaded)
      XCTAssertEqual(span.endTime, loaded.addingTimeInterval(0.2))
      XCTAssertEqual(ScreenTestFixtures.string(span.attributes[SemanticConventions.App.screenName.rawValue]),
                     "StoriesViewController")
      XCTAssertEqual(ScreenTestFixtures.string(span.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "uikit")
    }

    @MainActor
    func testAppearingAgainReportsNoSecondSpan() {
      let handler = makeHandler()
      let viewController = StoriesViewController()
      handler.onViewDidLoad(viewController)
      handler.onViewDidAppear(viewController)
      tracker.setCurrent(screen: "Comments", type: .uikit)
      handler.onViewDidAppear(viewController)

      XCTAssertEqual(timeToFirstAppearSpans().count, 1)
      // Going back to the screen is still a navigation.
      XCTAssertEqual(navigationEvents().count, 3)
      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
    }

    @MainActor
    func testAScreenLoadedBeforeInstallStillReportsTheNavigation() {
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewDidAppear(viewController)

      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
      XCTAssertEqual(navigationEvents().count, 1)
      XCTAssertTrue(timeToFirstAppearSpans().isEmpty)
    }

    @MainActor
    func testAViewControllerThatOptsOutReportsNothing() {
      let handler = makeHandler()
      let viewController = SilentViewController()

      handler.onViewDidLoad(viewController)
      handler.onViewDidAppear(viewController)

      XCTAssertNil(tracker.currentScreen)
      XCTAssertTrue(navigationEvents().isEmpty)
      XCTAssertTrue(timeToFirstAppearSpans().isEmpty)
    }

    @MainActor
    func testTimingCanBeTurnedOffWithoutLosingTheScreen() {
      // The tracker owns this, so turning it off reaches SwiftUI screens too.
      tracker.recordsTimeToFirstAppear = false
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController)
      handler.onViewDidAppear(viewController)

      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
      XCTAssertTrue(timeToFirstAppearSpans().isEmpty)
    }

    private func navigationEvents() -> [ReadableLogRecord] {
      logs.records.filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
    }

    private func timeToFirstAppearSpans() -> [SpanData] {
      spans.spans.filter { $0.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstAppear.rawValue }
    }
  }
#endif

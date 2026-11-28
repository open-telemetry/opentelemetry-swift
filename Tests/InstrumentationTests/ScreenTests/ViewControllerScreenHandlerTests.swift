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
  import InstrumentationCommon
  import UIKit
  import XCTest

  private final class StoriesViewController: UIViewController {}

  private final class CommentsViewController: UIViewController {}

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
    private var frames: FakeFirstFrameReader!
    private var notificationCenter: NotificationCenter!

    override func setUp() {
      super.setUp()
      let providers = ScreenTestFixtures.registerRecordingProviders()
      spans = providers.spans
      logs = providers.logs
      tracker = ScreenTracker()
      frames = FakeFirstFrameReader()
      notificationCenter = NotificationCenter()
    }

    /// The test bundle, not the app bundle: that is where these view controllers live.
    @MainActor
    private func makeHandler(_ config: ScreenUIKitConfig? = nil) -> ViewControllerScreenHandler {
      ViewControllerScreenHandler(
        config: config ?? ScreenUIKitConfig(bundle: Bundle(for: ViewControllerScreenHandlerTests.self)),
        screenTracker: tracker,
        firstFrameReader: frames,
        notificationCenter: notificationCenter
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
    func testSkipsAViewControllerFromABundleNestedInTheConfiguredOne() throws {
      // The test bundle sits inside its parent directory the way App.app/Frameworks/X.framework
      // sits inside App.app.
      let testBundlePath = Bundle(for: ViewControllerScreenHandlerTests.self).bundlePath
      let parentPath = (testBundlePath as NSString).deletingLastPathComponent
      let parent = try XCTUnwrap(Bundle(path: parentPath))
      let handler = makeHandler(ScreenUIKitConfig(bundle: parent))

      XCTAssertFalse(handler.tracksScreen(StoriesViewController()))
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
    func testAppearingReportsTheScreenAndItsFirstDraw() {
      let handler = makeHandler()
      let loaded = Date(timeIntervalSince1970: 1_700_000_000)
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController, now: loaded)
      handler.onViewWillAppear(viewController)
      frames.fire(at: loaded.addingTimeInterval(0.1))
      handler.onViewDidAppear(viewController, now: loaded.addingTimeInterval(0.4))

      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
      XCTAssertEqual(navigationEvents().count, 1)

      let span = timeToFirstDrawSpans().first
      guard let span else { return XCTFail("expected a time_to_first_draw span") }
      XCTAssertEqual(span.startTime, loaded)
      // The first frame, not viewDidAppear, which waits for the transition animation.
      XCTAssertEqual(span.endTime, loaded.addingTimeInterval(0.1))
      XCTAssertEqual(ScreenTestFixtures.string(span.attributes[SemanticConventions.App.screenName.rawValue]),
                     "StoriesViewController")
      XCTAssertEqual(ScreenTestFixtures.string(span.attributes[FederatedSemanticConventions.App.screenType.rawValue]), "uikit")
    }

    @MainActor
    func testAppearingAgainReportsNoSecondSpan() {
      let handler = makeHandler()
      let viewController = StoriesViewController()
      handler.onViewDidLoad(viewController)
      handler.onViewWillAppear(viewController)
      frames.fire(at: Date())
      handler.onViewDidAppear(viewController)
      tracker.setCurrent(screen: "Comments", type: .uikit)
      handler.onViewWillAppear(viewController)
      frames.fire(at: Date())
      handler.onViewDidAppear(viewController)

      XCTAssertEqual(timeToFirstDrawSpans().count, 1)
      // Going back to the screen is still a navigation.
      XCTAssertEqual(navigationEvents().count, 3)
      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
    }

    @MainActor
    func testAScreenLoadedBeforeInstallStillReportsTheNavigation() {
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewWillAppear(viewController)
      frames.fire(at: Date())
      handler.onViewDidAppear(viewController)

      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
      XCTAssertEqual(navigationEvents().count, 1)
      XCTAssertTrue(timeToFirstDrawSpans().isEmpty)
    }

    @MainActor
    func testAViewControllerThatOptsOutReportsNothing() {
      let handler = makeHandler()
      let viewController = SilentViewController()

      handler.onViewDidLoad(viewController)
      handler.onViewWillAppear(viewController)
      frames.fire(at: Date())
      handler.onViewDidAppear(viewController)

      XCTAssertNil(tracker.currentScreen)
      XCTAssertTrue(navigationEvents().isEmpty)
      XCTAssertTrue(timeToFirstDrawSpans().isEmpty)
    }

    @MainActor
    func testTimingCanBeTurnedOffWithoutLosingTheScreen() {
      // The tracker owns this, so turning it off reaches SwiftUI screens too.
      tracker.recordsTimeToFirstDraw = false
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController)
      handler.onViewWillAppear(viewController)
      frames.fire(at: Date())
      handler.onViewDidAppear(viewController)

      XCTAssertEqual(tracker.currentScreen, "StoriesViewController")
      XCTAssertTrue(timeToFirstDrawSpans().isEmpty)
    }

    @MainActor
    func testNoSpanUntilTheFirstFrameIsDisplayed() {
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController)
      handler.onViewWillAppear(viewController)

      XCTAssertTrue(timeToFirstDrawSpans().isEmpty)
      XCTAssertEqual(frames.pendingCount, 1)
    }

    @MainActor
    func testAppearingTwiceBeforeTheFrameStartsOneRead() {
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController)
      handler.onViewWillAppear(viewController)
      handler.onViewWillAppear(viewController)

      XCTAssertEqual(frames.pendingCount, 1)
    }

    @MainActor
    func testEnteringTheBackgroundCancelsAPendingDraw() {
      let handler = makeHandler()
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController)
      handler.onViewWillAppear(viewController)
      notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
      frames.fire(at: Date())

      XCTAssertEqual(frames.cancelledCount, 1)
      XCTAssertTrue(timeToFirstDrawSpans().isEmpty)
    }

    @MainActor
    func testAScreenBackgroundedBeforeItsFirstDrawMeasuresOnItsNextAppearance() {
      let handler = makeHandler()
      let loaded = Date(timeIntervalSince1970: 1_700_000_000)
      let viewController = StoriesViewController()

      handler.onViewDidLoad(viewController, now: loaded)
      handler.onViewWillAppear(viewController)
      notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
      handler.onViewWillAppear(viewController)
      frames.fire(at: loaded.addingTimeInterval(5))

      XCTAssertEqual(timeToFirstDrawSpans().count, 1)
      XCTAssertEqual(timeToFirstDrawSpans().first?.startTime, loaded)
      XCTAssertEqual(timeToFirstDrawSpans().first?.endTime, loaded.addingTimeInterval(5))
    }

    // MARK: - Navigation type

    @MainActor
    func testAContainerCallLabelsTheScreenItLeadsTo() {
      let handler = makeHandler()
      let comments = CommentsViewController()

      handler.recordNavigation(.push, target: comments, in: nil)
      handler.onViewDidAppear(comments)

      XCTAssertEqual(navigationTypes(), ["push"])
    }

    @MainActor
    func testATargetThatContainsTheScreenLabelsIt() {
      let handler = makeHandler()
      let comments = CommentsViewController()
      let flow = UINavigationController(rootViewController: comments)

      handler.recordNavigation(.modal, target: flow, in: nil)
      handler.onViewDidAppear(comments)

      XCTAssertEqual(navigationTypes(), ["modal"])
    }

    @MainActor
    func testACallForAnotherScreenLeavesThisOneUnlabelled() {
      let handler = makeHandler()
      tracker.setCurrent(screen: "Settings", type: .swiftui)

      handler.recordNavigation(.push, target: CommentsViewController(), in: nil)
      handler.onViewDidAppear(StoriesViewController())

      XCTAssertEqual(navigationTypes(), ["initial", nil])
    }

    @MainActor
    func testACancelledTransitionLeavesNoLabel() throws {
      let handler = makeHandler()
      let stories = StoriesViewController()

      tracker.setCurrent(screen: "Settings", type: .swiftui)
      let pending = handler.recordNavigation(.pop, target: stories, in: nil)
      handler.discard(try XCTUnwrap(pending))
      handler.onViewDidAppear(stories)

      XCTAssertEqual(navigationTypes(), ["initial", nil])
    }

    @MainActor
    func testEachCallLabelsOneAppearance() {
      let handler = makeHandler()
      let stories = StoriesViewController()
      let comments = CommentsViewController()

      handler.recordNavigation(.push, target: comments, in: nil)
      handler.onViewDidAppear(stories)
      handler.onViewDidAppear(comments)
      handler.onViewDidAppear(stories)

      XCTAssertEqual(navigationTypes(), ["initial", "push", nil])
    }

    @MainActor
    func testTheCurrentScreenAppearingAgainReportsNothing() {
      // A cancelled interactive pop or swipe-down calls viewDidAppear again on the screen the user
      // never left.
      let handler = makeHandler()
      let comments = CommentsViewController()

      handler.onViewDidAppear(comments)
      handler.onViewDidAppear(comments)

      XCTAssertEqual(navigationEvents().count, 1)
    }

    @MainActor
    func testASecondInstanceOfTheCurrentScreenIsStillANavigation() {
      let handler = makeHandler()
      let first = CommentsViewController()
      let second = CommentsViewController()

      handler.onViewDidAppear(first)
      handler.recordNavigation(.push, target: second, in: nil)
      handler.onViewDidAppear(second)

      XCTAssertEqual(navigationTypes(), ["initial", "push"])
      XCTAssertEqual(ScreenTestFixtures.string(navigationEvents().last?.attributes[FederatedSemanticConventions.App.screenPreviousName.rawValue]),
                     "CommentsViewController")
    }

    @MainActor
    func testACallOnAContainerOffScreenIsIgnored() {
      // A container builds its first stack before it is in a window; that is set-up, not
      // navigation.
      let handler = makeHandler()

      XCTAssertNil(handler.recordNavigation(.push, target: CommentsViewController(), in: UINavigationController()))
    }

    @MainActor
    func testTurningNavigationOffDropsTheType() {
      tracker = ScreenTracker(tracksNavigation: false)
      let handler = makeHandler()
      let comments = CommentsViewController()

      XCTAssertNil(handler.recordNavigation(.push, target: comments, in: nil))
      handler.onViewDidAppear(comments)

      XCTAssertEqual(navigationTypes(), [nil])
      XCTAssertEqual(tracker.currentScreen, "CommentsViewController")
    }

    @MainActor
    func testSettingTheStackClassifiesTheChange() {
      let root = StoriesViewController()
      let middle = CommentsViewController()
      let top = CommentsViewController()
      let other = CommentsViewController()

      XCTAssertEqual(ViewControllerScreenHandler.navigation(replacing: [root], with: [root, middle]), .push)
      XCTAssertEqual(ViewControllerScreenHandler.navigation(replacing: [root, middle], with: [root]), .pop)
      XCTAssertEqual(ViewControllerScreenHandler.navigation(replacing: [root, middle, top], with: [root]), .popTo)
      XCTAssertEqual(ViewControllerScreenHandler.navigation(replacing: [root, middle], with: [root, other]), .replace)
      XCTAssertEqual(ViewControllerScreenHandler.navigation(replacing: [root, middle], with: [other]), .reset)
      XCTAssertNil(ViewControllerScreenHandler.navigation(replacing: [root, middle], with: [other, middle]))
      XCTAssertNil(ViewControllerScreenHandler.navigation(replacing: [root], with: []))
    }

    @MainActor
    func testPoppingLevelsClassifiesTheChange() {
      XCTAssertNil(ViewControllerScreenHandler.navigation(poppingLevels: 0))
      XCTAssertEqual(ViewControllerScreenHandler.navigation(poppingLevels: 1), .pop)
      XCTAssertEqual(ViewControllerScreenHandler.navigation(poppingLevels: 3), .popTo)
    }

    @MainActor
    func testTheVisibleLeafFollowsNavigationAndTabContainers() {
      let stories = StoriesViewController()
      let comments = CommentsViewController()
      let navigation = UINavigationController(rootViewController: stories)
      navigation.pushViewController(comments, animated: false)
      let settings = StoriesViewController()
      let tabs = UITabBarController()
      tabs.viewControllers = [navigation, settings]
      tabs.selectedIndex = 0

      XCTAssertTrue(ViewControllerScreenHandler.visibleLeaf(from: tabs, excluding: nil) === comments)
      tabs.selectedIndex = 1
      XCTAssertTrue(ViewControllerScreenHandler.visibleLeaf(from: tabs, excluding: nil) === settings)
    }

    @MainActor
    func testADismissedPresentationReturnsToTheScreenBeforeIt() {
      // An unanimated dismissal can finish before viewDidDisappear, and a SwiftUI presenter gets
      // no callback, so the screen recorded at presentation is where the dismissal returns.
      let handler = makeHandler()
      tracker.setCurrent(screen: "Settings", type: .swiftui)
      let login = CommentsViewController()
      let flow = UINavigationController(rootViewController: login)

      handler.recordPresentation(of: flow, by: UIViewController())
      handler.recordNavigation(.modal, target: flow, in: nil)
      handler.onViewDidAppear(login)
      handler.onViewDidDisappear(login)

      XCTAssertEqual(navigationTypes(), ["initial", "modal", "dismiss"])
      XCTAssertEqual(tracker.currentScreen, "Settings")
      XCTAssertEqual(tracker.currentScreenType, .swiftui)
      XCTAssertEqual(ScreenTestFixtures.string(navigationEvents().last?.attributes[FederatedSemanticConventions.App.screenType.rawValue]),
                     "swiftui")
    }

    @MainActor
    func testAScreenThatDisappearsWithoutADismissalReportsNothing() {
      let handler = makeHandler()
      let comments = CommentsViewController()

      handler.onViewDidAppear(comments)
      handler.onViewDidDisappear(comments)

      XCTAssertEqual(navigationEvents().count, 1)
      XCTAssertEqual(tracker.currentScreen, "CommentsViewController")
    }

    @MainActor
    func testAScreenWithNoFlagsAndNoCallHasNoInferredType() {
      XCTAssertNil(ViewControllerScreenHandler.inferredNavigation(for: StoriesViewController()))
    }

    private func navigationTypes() -> [String?] {
      navigationEvents().map {
        ScreenTestFixtures.string($0.attributes[FederatedSemanticConventions.App.navigationType.rawValue])
      }
    }

    private func navigationEvents() -> [ReadableLogRecord] {
      logs.records.filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
    }

    private func timeToFirstDrawSpans() -> [SpanData] {
      spans.spans.filter { $0.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue }
    }
  }
#endif

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(UIKit) && !os(watchOS)
  import Foundation
  import InstrumentationCommon
  import ScreenInstrumentation
  import OpenTelemetryApi
  import UIKit

  /// What the instrumentation remembers about one view controller instance.
  ///
  /// Per instance, not per class: two windows showing the same screen each measure their own
  /// first draw.
  final class ScreenTrackingState {
    /// When `viewDidLoad` ran, which starts the time to first draw.
    let loadTime: Date
    var didStartFirstDraw = false

    init(loadTime: Date) {
      self.loadTime = loadTime
    }
  }

  /// SwiftUI's `UIHostingController` is generic and public API offers no non-generic base to
  /// test against, so a hosting controller is recognised by its class name.
  private let hostingControllerClassName = "UIHostingController"

  /// A first-draw read that has not reported yet.
  private final class PendingDraw {
    let state: ScreenTrackingState
    var read: FirstFrameRead?
    var isDone = false

    init(state: ScreenTrackingState) {
      self.state = state
    }
  }

  /// A container call waiting for the screen it leads to.
  ///
  /// The call states the kind of navigation, but the screen change it causes arrives later, in
  /// `viewDidAppear(_:)`. Matching by target keeps a call on a container this front end does not
  /// track, such as SwiftUI's, from labelling an unrelated screen.
  final class PendingNavigation {
    let type: NavigationType
    weak var target: UIViewController?

    init(type: NavigationType, target: UIViewController) {
      self.type = type
      self.target = target
    }
  }

  /// What was on screen when a presentation began, held weakly so it keeps nothing alive.
  final class PresentationRecord {
    weak var presented: UIViewController?
    weak var window: UIWindow?
    let screen: String
    let type: ScreenType

    init(presented: UIViewController, window: UIWindow?, screen: String, type: ScreenType) {
      self.presented = presented
      self.window = window
      self.screen = screen
      self.type = type
    }
  }

  /// Turns view controller lifecycle calls into screen changes and
  /// `app.screen.time_to_first_draw` spans.
  ///
  /// The swizzled methods do nothing but call in here, so the whole decision — whether to track
  /// the screen, what to call it, what to record — is testable without swizzling anything.
  @MainActor
  final class ViewControllerScreenHandler {
    private let config: ScreenUIKitConfig
    private let screenTracker: ScreenTracker
    private let firstFrameReader: FirstFrameReader
    private var pendingDraws: [ObjectIdentifier: PendingDraw] = [:]
    private var backgroundObserver: NSObjectProtocol?
    private var pendingNavigations: [PendingNavigation] = []
    /// The screen that was current when each live presentation began, keyed by the presented
    /// view controller. A dismissal that reveals a screen this front end does not track, such as
    /// a SwiftUI one, returns to it.
    private var screensBeforePresentation: [ObjectIdentifier: PresentationRecord] = [:]
    /// The view controller this front end last reported as current.
    private weak var currentViewController: UIViewController?
    /// Pending calls kept at once. A call whose screen never appears, such as a push onto a
    /// container that is torn down, would otherwise stay forever.
    private static let maxPendingNavigations = 8

    /// - Parameters:
    ///   - firstFrameReader: Reports the frame that first displays a screen.
    ///   - notificationCenter: Where to observe the app entering the background, which cancels
    ///     reads still waiting for a frame.
    init(config: ScreenUIKitConfig,
         screenTracker: ScreenTracker,
         firstFrameReader: FirstFrameReader = DisplayLinkFirstFrameReader(),
         notificationCenter: NotificationCenter = .default) {
      self.config = config
      self.screenTracker = screenTracker
      self.firstFrameReader = firstFrameReader
      backgroundObserver = notificationCenter.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.cancelPendingDraws() }
      }
    }

    /// Records when the screen was created, which starts the time to first draw.
    ///
    /// The current screen is not changed here. A view controller can load long before it
    /// appears, and loads without ever appearing, so loading is not evidence that the user is
    /// looking at it.
    func onViewDidLoad(_ viewController: UIViewController, now: Date = Date()) {
      guard tracksScreen(viewController) else { return }

      viewController.screenTrackingState = ScreenTrackingState(loadTime: now)
    }

    /// Starts waiting for the frame that first displays the screen.
    ///
    /// UIKit calls `viewWillAppear(_:)` before it configures the transition's animations, in the
    /// same transaction as the first layout, so the next frame displayed is the screen's first.
    func onViewWillAppear(_ viewController: UIViewController) {
      // A view controller that loaded before install() has no state, so it has no load time and
      // no measurable first draw.
      guard tracksScreen(viewController),
            let state = viewController.screenTrackingState,
            !state.didStartFirstDraw else { return }
      state.didStartFirstDraw = true

      let screen = screenName(viewController)
      let loadTime = state.loadTime
      let tracker = screenTracker
      let pending = PendingDraw(state: state)
      let key = ObjectIdentifier(pending)
      let read = firstFrameReader.readFirstFrame { [weak self] drawTime in
        pending.isDone = true
        MainActor.assumeIsolated { _ = self?.pendingDraws.removeValue(forKey: key) }
        tracker.recordTimeToFirstDraw(screen: screen,
                                      type: .uikit,
                                      loadTime: loadTime,
                                      drawTime: drawTime)
      }
      guard !pending.isDone else { return }
      pending.read = read
      pendingDraws[key] = pending
    }

    /// Reports the screen as current, with the kind of navigation that brought it when known.
    ///
    /// A view controller that is already current reports nothing, which covers a cancelled
    /// interactive pop or swipe-down: UIKit calls `viewDidAppear(_:)` again on the screen the user
    /// never left.
    func onViewDidAppear(_ viewController: UIViewController, now: Date = Date()) {
      guard tracksScreen(viewController) else { return }
      let screen = screenName(viewController)

      guard screenTracker.tracksNavigation else {
        screenTracker.setCurrent(screen: screen, type: .uikit, timestamp: now)
        return
      }
      if viewController === currentViewController, screenTracker.currentScreen == screen {
        return
      }

      // With nothing current yet, leave the type to the tracker, which labels the first screen of
      // the process `initial`.
      let navigation = consumeNavigation(leadingTo: viewController)
        ?? (screenTracker.currentScreen == nil ? nil : Self.inferredNavigation(for: viewController))
      currentViewController = viewController
      screenTracker.setCurrent(screen: screen, type: .uikit, navigation: navigation, timestamp: now)
    }

    /// Reports the screen a dismissal reveals.
    ///
    /// Dismissing a `.pageSheet`, `.formSheet` or `.overFullScreen` presentation calls no
    /// `viewDidAppear(_:)` on the presenter, so without this the tracker would keep naming the
    /// dismissed screen. When the current screen disappears because it, or a container holding it,
    /// is being dismissed, walk down from its window's root to the screen now showing.
    ///
    /// A dismissal shows as `isBeingDismissed` on the presented view controller or a parent. An
    /// unanimated one can finish before `viewDidDisappear(_:)`, so a presentation this front end
    /// recorded that has lost its presenter counts as dismissed too.
    func onViewDidDisappear(_ viewController: UIViewController, now: Date = Date()) {
      guard screenTracker.tracksNavigation,
            viewController === currentViewController,
            let dismissed = dismissedAncestor(of: viewController) else { return }

      let before = screensBeforePresentation.removeValue(forKey: ObjectIdentifier(dismissed))
      let root = dismissed.presentingViewController?.viewIfLoaded?.window?.rootViewController
        ?? before?.window?.rootViewController
      currentViewController = nil
      if let root {
        let revealed = Self.visibleLeaf(from: root, excluding: dismissed)
        if tracksScreen(revealed) {
          currentViewController = revealed
          screenTracker.setCurrent(screen: screenName(revealed), type: .uikit, navigation: .dismiss, timestamp: now)
          return
        }
      }
      // A revealed screen this front end does not track, such as a SwiftUI one, gets no
      // callback of its own, so return to the screen that was current when the presentation
      // began.
      guard let before else { return }
      screenTracker.setCurrent(screen: before.screen, type: before.type, navigation: .dismiss, timestamp: now)
    }

    /// The outermost of `viewController` and its parents that is being, or has been, dismissed.
    private func dismissedAncestor(of viewController: UIViewController) -> UIViewController? {
      let chain = Self.ancestors(of: viewController)
      if let dismissing = chain.last(where: \.isBeingDismissed) {
        return dismissing
      }
      return chain.last { candidate in
        candidate.presentingViewController == nil && screensBeforePresentation[ObjectIdentifier(candidate)] != nil
      }
    }

    /// Remembers the current screen and the presenter's window as `presented` goes up, for its
    /// dismissal to return to.
    func recordPresentation(of presented: UIViewController, by presenter: UIViewController) {
      guard screenTracker.tracksNavigation,
            let screen = screenTracker.currentScreen,
            let type = screenTracker.currentScreenType else { return }
      screensBeforePresentation = screensBeforePresentation.filter { $0.value.presented != nil }
      screensBeforePresentation[ObjectIdentifier(presented)] = PresentationRecord(
        presented: presented, window: presenter.viewIfLoaded?.window, screen: screen, type: type)
    }

    // MARK: - Container calls

    /// Remembers that a container call will lead to `target`, unless navigation tracking is off
    /// or the container is not on screen. A container builds its first stack before it is in a
    /// window, and those calls are set-up, not navigation.
    @discardableResult
    func recordNavigation(_ type: NavigationType?,
                          target: UIViewController?,
                          in container: UIViewController?) -> PendingNavigation? {
      guard screenTracker.tracksNavigation, let type, let target else { return nil }
      if let container, container.viewIfLoaded?.window == nil { return nil }

      pendingNavigations.removeAll { $0.target == nil }
      if pendingNavigations.count >= Self.maxPendingNavigations {
        pendingNavigations.removeFirst()
      }
      let pending = PendingNavigation(type: type, target: target)
      pendingNavigations.append(pending)
      return pending
    }

    /// Drops `pending` if its transition is cancelled. An interactive pop or swipe-down calls the
    /// container method as the gesture starts, before the user commits.
    func discardIfCancelled(_ pending: PendingNavigation?, coordinator: UIViewControllerTransitionCoordinator?) {
      guard let pending, let coordinator else { return }
      coordinator.animate(alongsideTransition: nil) { [weak self] context in
        guard context.isCancelled else { return }
        MainActor.assumeIsolated { self?.discard(pending) }
      }
    }

    func discard(_ pending: PendingNavigation) {
      pendingNavigations.removeAll { $0 === pending }
    }

    /// Takes the latest pending call whose target is `viewController` or contains it.
    private func consumeNavigation(leadingTo viewController: UIViewController) -> NavigationType? {
      guard let index = pendingNavigations.lastIndex(where: { pending in
        guard let target = pending.target else { return false }
        return Self.ancestors(of: viewController).contains { $0 === target }
      }) else { return nil }
      return pendingNavigations.remove(at: index).type
    }

    // MARK: - Classification

    /// The kind of navigation a screen's own flags show when no container call was seen: a
    /// presentation or a push. A revealed screen carries neither flag, so it gets no type.
    static func inferredNavigation(for viewController: UIViewController) -> NavigationType? {
      let chain = ancestors(of: viewController)
      if chain.contains(where: \.isBeingPresented) { return .modal }
      if chain.contains(where: \.isMovingToParent) { return .push }
      return nil
    }

    /// The kind of navigation `setViewControllers(_:animated:)` makes, from the stack before and
    /// after. `nil` when the top does not change.
    static func navigation(replacing old: [UIViewController], with new: [UIViewController]) -> NavigationType? {
      guard let newTop = new.last, old.last !== newTop else { return nil }
      if new.count > old.count, zip(old, new).allSatisfy({ $0 === $1 }) {
        return .push
      }
      if new.count < old.count, zip(new, old).allSatisfy({ $0 === $1 }) {
        return old.count - new.count == 1 ? .pop : .popTo
      }
      if new.count == old.count, zip(old.dropLast(), new.dropLast()).allSatisfy({ $0 === $1 }) {
        return .replace
      }
      return .reset
    }

    /// The kind of navigation a pop of `levels` screens makes.
    static func navigation(poppingLevels levels: Int) -> NavigationType? {
      switch levels {
      case ..<1: nil
      case 1: .pop
      default: .popTo
      }
    }

    /// `viewController` and its parents, innermost first.
    static func ancestors(of viewController: UIViewController) -> [UIViewController] {
      var chain: [UIViewController] = []
      var current: UIViewController? = viewController
      while let candidate = current {
        chain.append(candidate)
        current = candidate.parent
      }
      return chain
    }

    /// The screen showing under `root`: follow presentations, skipping `dismissed`, then the top
    /// of each navigation controller and the selection of each tab bar controller.
    static func visibleLeaf(from root: UIViewController, excluding dismissed: UIViewController?) -> UIViewController {
      var current = root
      var visited: Set<ObjectIdentifier> = [ObjectIdentifier(root)]
      while true {
        let next: UIViewController?
        if let presented = current.presentedViewController,
           presented !== dismissed,
           !presented.isBeingDismissed,
           !visited.contains(ObjectIdentifier(presented)) {
          next = presented
        } else if let navigation = current as? UINavigationController {
          next = navigation.topViewController
        } else if let tabs = current as? UITabBarController {
          next = tabs.selectedViewController
        } else {
          next = nil
        }
        guard let next, visited.insert(ObjectIdentifier(next)).inserted else { return current }
        current = next
      }
    }

    /// Drops every read still waiting for a frame. A display link pauses in the background, so a
    /// read left running would end at a frame drawn after the user came back. The screen's next
    /// appearance measures again.
    func cancelPendingDraws() {
      let draws = pendingDraws.values
      pendingDraws.removeAll()
      for draw in draws {
        draw.read?.cancel()
        draw.state.didStartFirstDraw = false
      }
    }

    /// Whether to report `viewController` at all.
    ///
    /// A view controller that adopts `ScreenTrackingCustomization` decides for itself. Otherwise
    /// the class must come from the configured bundle itself, not a framework embedded in it,
    /// which keeps `UINavigationController`, `UITabBarController` and the rest of the frameworks'
    /// plumbing out of the data. A SwiftUI hosting controller is excluded unless
    /// `tracksHostingControllers` is on, because the `.otelScreen` modifier already names what it
    /// hosts.
    func tracksScreen(_ viewController: UIViewController) -> Bool {
      if let customized = viewController as? ScreenTrackingCustomization {
        return customized.tracksScreen
      }
      let viewControllerClass: AnyClass = type(of: viewController)
      if !config.tracksHostingControllers, Self.isHostingController(viewControllerClass) {
        return false
      }
      return Bundle(for: viewControllerClass).bundlePath == config.bundle.bundlePath
    }

    /// The name to report for `viewController`.
    func screenName(_ viewController: UIViewController) -> String {
      if let customized = viewController as? ScreenTrackingCustomization,
         let customName = customized.customScreenName {
        return customName
      }
      return Self.screenName(for: type(of: viewController))
    }

    /// The class name with its module prefix and generic arguments removed.
    ///
    /// `String(describing:)` on a specialized generic gives
    /// `UIHostingController<SettingsView>`, and `NSStringFromClass` gives the mangled
    /// `_TtGC7SwiftUI19UIHostingController...`. Neither reads well on a dashboard, so take the
    /// base name.
    static func screenName(for viewControllerClass: AnyClass) -> String {
      let described = String(describing: viewControllerClass)
      let base = described.prefix { $0 != "<" }
      return base.split(separator: ".").last.map(String.init) ?? String(base)
    }

    /// Whether any class in the chain is a SwiftUI hosting controller.
    static func isHostingController(_ viewControllerClass: AnyClass) -> Bool {
      var current: AnyClass? = viewControllerClass
      while let candidate = current {
        if String(describing: candidate).hasPrefix(hostingControllerClassName) {
          return true
        }
        current = class_getSuperclass(candidate)
      }
      return false
    }
  }
#endif

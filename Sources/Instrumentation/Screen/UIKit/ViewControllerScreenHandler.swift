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

    /// Reports the screen as current.
    func onViewDidAppear(_ viewController: UIViewController, now: Date = Date()) {
      guard tracksScreen(viewController) else { return }

      screenTracker.setCurrent(screen: screenName(viewController), type: .uikit, timestamp: now)
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

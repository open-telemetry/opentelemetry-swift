/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(UIKit) && !os(watchOS)
  import Foundation
  import ScreenInstrumentation
  import OpenTelemetryApi
  import UIKit

  /// What the instrumentation remembers about one view controller instance.
  ///
  /// Per instance, not per class: two windows showing the same screen each measure their own
  /// first appearance.
  final class ScreenTrackingState {
    /// When `viewDidLoad` ran, which starts the time to first appear.
    let loadTime: Date
    var didReportFirstAppear = false

    init(loadTime: Date) {
      self.loadTime = loadTime
    }
  }

  /// Turns view controller lifecycle calls into screen changes and
  /// `app.screen.time_to_first_appear` spans.
  ///
  /// The swizzled methods do nothing but call in here, so the whole decision — whether to track
  /// the screen, what to call it, what to record — is testable without swizzling anything.
  @MainActor
  final class ViewControllerScreenHandler {
    private let config: ScreenUIKitConfig
    private let screenTracker: ScreenTracker

    init(config: ScreenUIKitConfig, screenTracker: ScreenTracker) {
      self.config = config
      self.screenTracker = screenTracker
    }

    /// Records when the screen was created, which starts the time to first appear.
    ///
    /// The current screen is not changed here. A view controller can load long before it
    /// appears, and loads without ever appearing, so loading is not evidence that the user is
    /// looking at it.
    func onViewDidLoad(_ viewController: UIViewController, now: Date = Date()) {
      guard tracksScreen(viewController) else { return }

      viewController.screenTrackingState = ScreenTrackingState(loadTime: now)
    }

    /// Reports the screen as current, then records its first appearance.
    func onViewDidAppear(_ viewController: UIViewController, now: Date = Date()) {
      guard tracksScreen(viewController) else { return }
      let screen = screenName(viewController)

      // Before the span, so ScreenSpanProcessor stamps the span with this screen rather than the
      // one the user just left.
      screenTracker.setCurrent(screen: screen, type: .uikit, timestamp: now)


      // A view controller that loaded before install() has no state, so it has no load time and
      // no measurable first appearance. It still reports the screen change above.
      guard let state = viewController.screenTrackingState,
            !state.didReportFirstAppear else { return }
      state.didReportFirstAppear = true

      screenTracker.recordTimeToFirstAppear(screen: screen,
                                            type: .uikit,
                                            loadTime: state.loadTime,
                                            appearTime: now)
    }

    /// Whether to report `viewController` at all.
    ///
    /// A view controller that adopts `ScreenTrackingCustomization` decides for itself. Otherwise
    /// the class must come from the configured bundle, which keeps `UINavigationController`,
    /// `UITabBarController` and the rest of the frameworks' plumbing out of the data. A SwiftUI
    /// hosting controller is excluded unless `tracksHostingControllers` is on, because the
    /// `.otelScreen` modifier already names what it hosts.
    func tracksScreen(_ viewController: UIViewController) -> Bool {
      if let customized = viewController as? ScreenTrackingCustomization {
        return customized.tracksScreen
      }
      let viewControllerClass: AnyClass = type(of: viewController)
      if !config.tracksHostingControllers, Self.isHostingController(viewControllerClass) {
        return false
      }
      return Bundle(for: viewControllerClass).bundlePath.hasPrefix(config.bundle.bundlePath)
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
        if String(describing: candidate).hasPrefix("UIHostingController") {
          return true
        }
        current = class_getSuperclass(candidate)
      }
      return false
    }
  }
#endif

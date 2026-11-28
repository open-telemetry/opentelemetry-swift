/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(UIKit) && !os(watchOS)
  import Foundation
  import ObjectiveC.runtime
  import os.log
  import UIKit

  /// One byte whose address keys the associated object. Allocating it gives an address no other
  /// framework can collide with, and it lives as long as the process.
  private nonisolated(unsafe) let screenTrackingStateKey = UnsafeRawPointer(
    UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
  )

  extension UIViewController {
    /// What the instrumentation remembers about this instance, or `nil` before it loaded.
    ///
    /// An associated object, so no view controller has to subclass anything and nothing is
    /// retained after the view controller goes away.
    var screenTrackingState: ScreenTrackingState? {
      get { objc_getAssociatedObject(self, screenTrackingStateKey) as? ScreenTrackingState }
      set {
        objc_setAssociatedObject(self, screenTrackingStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
    }

    /// The handler the swizzled methods call. Set once by `install`, read on the main thread.
    fileprivate static var screenHandler: ViewControllerScreenHandler?

    /// Exchanges `viewDidLoad`, `viewWillAppear(_:)` and `viewDidAppear(_:)` with the shims below,
    /// and, when `tracksNavigation` is on, `viewDidDisappear(_:)` and the container calls that
    /// navigate.
    ///
    /// Exchanging on `UIViewController` itself covers every view controller at once. A subclass
    /// that overrides a method reaches the shim through its `super` call, so a subclass that
    /// skips `super` is invisible to this instrumentation.
    static func installScreenTracking(handler: ViewControllerScreenHandler, tracksNavigation: Bool) {
      screenHandler = handler
      exchange(#selector(UIViewController.viewDidLoad), with: #selector(UIViewController.otelTraceViewDidLoad))
      exchange(#selector(UIViewController.viewWillAppear(_:)), with: #selector(UIViewController.otelTraceViewWillAppear(_:)))
      exchange(#selector(UIViewController.viewDidAppear(_:)), with: #selector(UIViewController.otelTraceViewDidAppear(_:)))
      guard tracksNavigation else { return }

      exchange(#selector(UIViewController.viewDidDisappear(_:)), with: #selector(UIViewController.otelTraceViewDidDisappear(_:)))
      exchange(#selector(UIViewController.present(_:animated:completion:)),
               with: #selector(UIViewController.otelTracePresent(_:animated:completion:)))
      exchange(#selector(UINavigationController.pushViewController(_:animated:)),
               with: #selector(UINavigationController.otelTracePushViewController(_:animated:)),
               on: UINavigationController.self)
      exchange(#selector(UINavigationController.popViewController(animated:)),
               with: #selector(UINavigationController.otelTracePopViewController(animated:)),
               on: UINavigationController.self)
      exchange(#selector(UINavigationController.popToRootViewController(animated:)),
               with: #selector(UINavigationController.otelTracePopToRootViewController(animated:)),
               on: UINavigationController.self)
      exchange(#selector(UINavigationController.popToViewController(_:animated:)),
               with: #selector(UINavigationController.otelTracePopToViewController(_:animated:)),
               on: UINavigationController.self)
      exchange(#selector(UINavigationController.setViewControllers(_:animated:)),
               with: #selector(UINavigationController.otelTraceSetViewControllers(_:animated:)),
               on: UINavigationController.self)
      // Both setters: setting `selectedIndex` in code does not go through the view controller
      // setter, and a tap on a tab does.
      exchange(#selector(setter: UITabBarController.selectedIndex),
               with: #selector(UITabBarController.otelTraceSetSelectedIndex(_:)),
               on: UITabBarController.self)
      exchange(#selector(setter: UITabBarController.selectedViewController),
               with: #selector(UITabBarController.otelTraceSetSelectedViewController(_:)),
               on: UITabBarController.self)
      exchange(#selector(setter: UIWindow.rootViewController),
               with: #selector(UIWindow.otelTraceSetRootViewController(_:)),
               on: UIWindow.self)
    }

    private static func exchange(_ original: Selector, with replacement: Selector, on owner: AnyClass = UIViewController.self) {
      guard let originalMethod = class_getInstanceMethod(owner, original),
            let replacementMethod = class_getInstanceMethod(owner, replacement) else {
        os_log(.error, "screen instrumentation: no method to swizzle for %{public}@", NSStringFromSelector(original))
        return
      }
      method_exchangeImplementations(originalMethod, replacementMethod)
    }

    // MARK: - Shims
    //
    // `dynamic` matters: it sends the message through the Objective-C runtime, so the call below
    // reaches the exchanged implementation instead of recursing into this shim.

    @objc dynamic func otelTraceViewDidLoad() {
      UIViewController.screenHandler?.onViewDidLoad(self)
      otelTraceViewDidLoad() // The original viewDidLoad, after the exchange.
    }

    @objc dynamic func otelTraceViewWillAppear(_ animated: Bool) {
      UIViewController.screenHandler?.onViewWillAppear(self)
      otelTraceViewWillAppear(animated) // The original viewWillAppear, after the exchange.
    }

    @objc dynamic func otelTraceViewDidAppear(_ animated: Bool) {
      UIViewController.screenHandler?.onViewDidAppear(self)
      otelTraceViewDidAppear(animated) // The original viewDidAppear, after the exchange.
    }

    @objc dynamic func otelTraceViewDidDisappear(_ animated: Bool) {
      otelTraceViewDidDisappear(animated) // The original viewDidDisappear, after the exchange.
      UIViewController.screenHandler?.onViewDidDisappear(self)
    }

    @objc dynamic func otelTracePresent(_ viewController: UIViewController,
                                        animated: Bool,
                                        completion: (() -> Void)?) {
      UIViewController.screenHandler?.recordNavigation(.modal, target: viewController, in: self)
      UIViewController.screenHandler?.recordPresentation(of: viewController, by: self)
      otelTracePresent(viewController, animated: animated, completion: completion)
    }
  }

  // Each shim records the kind of navigation before calling the original, so the pending call is
  // in place even when UIKit makes the change at once, then watches the transition so that an
  // interactive pop the user cancels is dropped.

  extension UINavigationController {
    @objc dynamic func otelTracePushViewController(_ viewController: UIViewController, animated: Bool) {
      let pending = UIViewController.screenHandler?.recordNavigation(.push, target: viewController, in: self)
      otelTracePushViewController(viewController, animated: animated)
      UIViewController.screenHandler?.discardIfCancelled(pending, coordinator: transitionCoordinator)
    }

    @objc dynamic func otelTracePopViewController(animated: Bool) -> UIViewController? {
      let stack = viewControllers
      let target = stack.count >= 2 ? stack[stack.count - 2] : nil
      let pending = UIViewController.screenHandler?.recordNavigation(.pop, target: target, in: self)
      let popped = otelTracePopViewController(animated: animated)
      UIViewController.screenHandler?.discardIfCancelled(pending, coordinator: transitionCoordinator)
      return popped
    }

    @objc dynamic func otelTracePopToRootViewController(animated: Bool) -> [UIViewController]? {
      let stack = viewControllers
      let pending = UIViewController.screenHandler?.recordNavigation(
        ViewControllerScreenHandler.navigation(poppingLevels: stack.count - 1), target: stack.first, in: self)
      let popped = otelTracePopToRootViewController(animated: animated)
      UIViewController.screenHandler?.discardIfCancelled(pending, coordinator: transitionCoordinator)
      return popped
    }

    @objc dynamic func otelTracePopToViewController(_ viewController: UIViewController,
                                                    animated: Bool) -> [UIViewController]? {
      let stack = viewControllers
      let levels = stack.lastIndex { $0 === viewController }.map { stack.count - 1 - $0 } ?? 0
      let pending = UIViewController.screenHandler?.recordNavigation(
        ViewControllerScreenHandler.navigation(poppingLevels: levels), target: viewController, in: self)
      let popped = otelTracePopToViewController(viewController, animated: animated)
      UIViewController.screenHandler?.discardIfCancelled(pending, coordinator: transitionCoordinator)
      return popped
    }

    @objc dynamic func otelTraceSetViewControllers(_ newViewControllers: [UIViewController], animated: Bool) {
      let pending = UIViewController.screenHandler?.recordNavigation(
        ViewControllerScreenHandler.navigation(replacing: viewControllers, with: newViewControllers),
        target: newViewControllers.last,
        in: self)
      otelTraceSetViewControllers(newViewControllers, animated: animated)
      UIViewController.screenHandler?.discardIfCancelled(pending, coordinator: transitionCoordinator)
    }
  }

  extension UITabBarController {
    @objc dynamic func otelTraceSetSelectedIndex(_ index: Int) {
      if index != selectedIndex, let tabs = viewControllers, tabs.indices.contains(index) {
        UIViewController.screenHandler?.recordNavigation(.switch, target: tabs[index], in: self)
      }
      otelTraceSetSelectedIndex(index)
    }

    @objc dynamic func otelTraceSetSelectedViewController(_ viewController: UIViewController?) {
      if let viewController, viewController !== selectedViewController {
        UIViewController.screenHandler?.recordNavigation(.switch, target: viewController, in: self)
      }
      otelTraceSetSelectedViewController(viewController)
    }
  }

  extension UIWindow {
    /// A new root replaces every screen in the window, as logging out does.
    @objc dynamic func otelTraceSetRootViewController(_ viewController: UIViewController?) {
      if rootViewController != nil, viewController !== rootViewController {
        UIViewController.screenHandler?.recordNavigation(.reset, target: viewController, in: nil)
      }
      otelTraceSetRootViewController(viewController)
    }
  }
#endif

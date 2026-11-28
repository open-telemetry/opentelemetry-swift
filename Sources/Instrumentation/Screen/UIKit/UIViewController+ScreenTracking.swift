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
    private static var screenHandler: ViewControllerScreenHandler?

    /// Exchanges `viewDidLoad`, `viewWillAppear(_:)` and `viewDidAppear(_:)` with the shims below.
    ///
    /// Exchanging on `UIViewController` itself covers every view controller at once. A subclass
    /// that overrides a method reaches the shim through its `super` call, so a subclass that
    /// skips `super` is invisible to this instrumentation.
    static func installScreenTracking(handler: ViewControllerScreenHandler) {
      screenHandler = handler
      exchange(#selector(UIViewController.viewDidLoad), with: #selector(UIViewController.otelTraceViewDidLoad))
      exchange(#selector(UIViewController.viewWillAppear(_:)), with: #selector(UIViewController.otelTraceViewWillAppear(_:)))
      exchange(#selector(UIViewController.viewDidAppear(_:)), with: #selector(UIViewController.otelTraceViewDidAppear(_:)))
    }

    private static func exchange(_ original: Selector, with replacement: Selector) {
      guard let originalMethod = class_getInstanceMethod(UIViewController.self, original),
            let replacementMethod = class_getInstanceMethod(UIViewController.self, replacement) else {
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
  }
#endif

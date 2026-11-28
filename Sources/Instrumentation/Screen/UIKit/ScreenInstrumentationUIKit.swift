/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import ScreenInstrumentation

#if canImport(UIKit) && !os(watchOS)
  import UIKit
#endif

/// Reports UIKit screens by swizzling `UIViewController`.
///
/// Call `install()` once, after registering the tracer and logger providers, and add
/// `ScreenSpanProcessor` and `ScreenLogRecordProcessor` from `ScreenInstrumentation` to those
/// providers so spans and log records carry `app.screen.name`.
///
/// ```swift
/// import ScreenInstrumentation
/// import ScreenInstrumentationUIKit
///
/// ScreenInstrumentationUIKit.install()
/// ```
///
/// Swizzling is process-wide and permanent, so `install()` does it once and later calls return.
/// An app with no UIKit screens links `ScreenInstrumentationSwiftUI` instead and never swizzles.
public enum ScreenInstrumentationUIKit {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var isInstalled = false

  /// Installs UIKit screen tracking with `config`, or returns if it is already installed.
  ///
  /// - Parameters:
  ///   - config: Which view controllers to report.
  ///   - screenTracker: The tracker to feed. Defaults to the shared one.
  @MainActor
  public static func install(config: ScreenUIKitConfig = .default,
                             screenTracker: ScreenTracker? = nil) {
    let shouldInstall: Bool = lock.withLock {
      guard !isInstalled else { return false }
      isInstalled = true
      return true
    }
    guard shouldInstall else { return }

    if let screenTracker {
      ScreenTrackerProvider.register(screenTracker: screenTracker)
    }
    let tracker = screenTracker ?? ScreenTrackerProvider.getInstance()
    tracker.recordsTimeToFirstDraw = config.recordsTimeToFirstDraw

    #if canImport(UIKit) && !os(watchOS)
      let handler = ViewControllerScreenHandler(config: config, screenTracker: tracker)
      UIViewController.installScreenTracking(handler: handler)
    #else
      _ = tracker
    #endif
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Thread-safe access to the one `ScreenTracker` the process shares.
///
/// The processors and both instrumentation paths must agree on one tracker, otherwise a span
/// carries a screen name from a tracker that no instrumentation feeds. Register one early, or
/// let the first caller create it.
///
/// ```swift
/// let tracker = ScreenTracker()
/// ScreenTrackerProvider.register(screenTracker: tracker)
/// let screen = ScreenTrackerProvider.getInstance().currentScreen
/// ```
public enum ScreenTrackerProvider {
  nonisolated(unsafe) private static var _instance: ScreenTracker?
  private static let lock = NSLock()

  /// Registers `screenTracker` as the shared tracker, replacing any earlier one.
  public static func register(screenTracker: ScreenTracker) {
    lock.withLock { _instance = screenTracker }
  }

  /// Returns the shared tracker, creating a default one on first use.
  public static func getInstance() -> ScreenTracker {
    lock.withLock {
      if _instance == nil {
        _instance = ScreenTracker()
      }
      return _instance!
    }
  }
}

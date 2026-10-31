/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  /// Decides whether the current process is a cold or warm launch. Called once per process.
  protocol LaunchTypeClassifier: Sendable {
    func classify() -> AppLaunchInstrumentationConfiguration.LaunchType
  }

  /// Infers the launch type by comparing the current launch's state with the previous launch's.
  struct InferredLaunchTypeClassifier: LaunchTypeClassifier {
    var currentLaunchContext: @Sendable () -> LaunchContext?
    var launchHistory: LaunchHistory

    /// A launch is warm when the device hasn't rebooted and the app hasn't been reinstalled or
    /// updated since the previous launch, so the system is likely to still have the app's code and
    /// data cached.
    func classify() -> AppLaunchInstrumentationConfiguration.LaunchType {
      guard let current = currentLaunchContext(),
            let previous = launchHistory.exchange(current),
            current.isSameState(as: previous) else { return .cold }
      return .warm
    }
  }
#endif

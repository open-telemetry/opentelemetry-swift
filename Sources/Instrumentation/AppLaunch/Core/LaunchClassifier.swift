/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import OpenTelemetryApi

  /// What kind of launch this process is, and any attributes that explain why.
  package struct LaunchClassification: @unchecked Sendable {
    package var type: AppLaunchInstrumentationConfiguration.LaunchType
    package var attributes: [String: AttributeValue]

    package init(type: AppLaunchInstrumentationConfiguration.LaunchType, attributes: [String: AttributeValue] = [:]) {
      self.type = type
      self.attributes = attributes
    }
  }

  /// Decides what kind of launch this process is.
  package protocol LaunchClassifier: Sendable {
    /// Called once per process when the instrumentation installs. The closure it returns is called
    /// when the launch's first activation happens, if it does, so a classifier can look at what the
    /// launch did.
    func begin() -> @Sendable () -> LaunchClassification
  }

  /// Infers the launch type by comparing the current launch's state with the previous launch's. It's
  /// the fallback for a launch whose pages can't be sampled.
  package struct InferredLaunchClassifier: LaunchClassifier {
    private let currentLaunchContext: @Sendable () -> LaunchContext?
    private let launchHistory: LaunchHistory

    package init(dependencies: AppLaunchRuntime.Dependencies) {
      currentLaunchContext = dependencies.currentLaunchContext
      launchHistory = dependencies.launchHistory
    }

    package func begin() -> @Sendable () -> LaunchClassification {
      let type = classify()
      return { LaunchClassification(type: type) }
    }

    /// A launch is warm when the device hasn't rebooted and the app hasn't been reinstalled or
    /// updated since the previous launch, so the system is likely to still have the app's code and
    /// data cached.
    private func classify() -> AppLaunchInstrumentationConfiguration.LaunchType {
      guard let current = currentLaunchContext(),
            let previous = launchHistory.exchange(current),
            current.isSameState(as: previous) else { return .cold }
      return .warm
    }
  }
#endif

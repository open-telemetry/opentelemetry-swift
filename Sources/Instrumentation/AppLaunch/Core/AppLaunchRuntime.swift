/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  import OpenTelemetryApi

  /// Installs and resets the activation monitor. There's one per process.
  package enum AppLaunchRuntime {
    // Matches the instrumentation scope used by OpenTelemetry Android.
    package static let instrumentationScope = "io.opentelemetry.lifecycle"

    package typealias LaunchType = AppLaunchInstrumentationConfiguration.LaunchType

    package struct Dependencies: Sendable {
      var notificationCenter: NotificationCenter = .default
      var didBecomeActiveNotification: Notification.Name = defaultDidBecomeActiveNotification
      var willEnterForegroundNotification: Notification.Name? = defaultWillEnterForegroundNotification
      var didEnterBackgroundNotification: Notification.Name? = defaultDidEnterBackgroundNotification
      var sceneWillConnectNotification: Notification.Name? = defaultSceneWillConnectNotification
      var didFinishLaunchingNotification: Notification.Name? = defaultDidFinishLaunchingNotification
      var firstFrameReader: FirstFrameReader? = defaultFirstFrameReader
      package var processStartTime: @Sendable () -> Date? = readProcessStartTime
      package var earliestAppCodeTime: @Sendable () -> Date? = readEarliestAppCodeTime
      package var isActivePrewarm: @Sendable () -> Bool = readIsActivePrewarm
      var isAppActive: @Sendable () -> Bool = readIsAppActive
      var isBackgroundLaunch: @Sendable () -> Bool = readIsBackgroundLaunch
      package var configuration = AppLaunchInstrumentationConfiguration()
      var currentLaunchContext: @Sendable () -> LaunchContext? = readCurrentLaunchContext
      var launchHistory: LaunchHistory = UserDefaultsLaunchHistory()
      var now: @Sendable () -> Date = Date.init
      // Runs the block once the main thread has finished handling the current event.
      var afterCurrentEvent: @Sendable (@escaping @Sendable () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
      // Builds the classifier that decides what kind of launch this process is.
      package var makeClassifier: @Sendable (Dependencies) -> LaunchClassifier

      // Builds the recorder that decides which activations are recorded, and records them.
      package var makeRecorder: @Sendable (Dependencies) -> AppStartRecording

      var classifier: LaunchClassifier { makeClassifier(self) }

      var recorder: AppStartRecording { makeRecorder(self) }
    }

    /// Whether the instrumentation is installed and observing app activations.
    package static var isInstalled: Bool {
      lock.withLock { _monitor != nil }
    }

    // Guards `_monitor`.
    private static let lock = NSLock()
    // Held for a whole install, so a concurrent install returns only once the first one is
    // observing activations. Notification callbacks never take it.
    private static let installLock = NSLock()
    nonisolated(unsafe) private static var _monitor: ActivationMonitor?

    package static func install(dependencies: Dependencies) {
      // Logged outside `installLock`, because the feedback handler is the app's code and could
      // call `install` again.
      switch installLock.withLock({ installLocked(dependencies: dependencies) }) {
      case let .alreadyInstalled(monitor):
        if monitor.configuration != dependencies.configuration {
          InternalLogger.error("already installed, so the new configuration is ignored.")
        }
      case let .installed(isAppActive, isBackgroundLaunch):
        InternalLogger.info("installed with the app active \(isAppActive) and background launch \(isBackgroundLaunch).")
      }
    }

    private enum InstallResult {
      case alreadyInstalled(ActivationMonitor)
      case installed(isAppActive: Bool, isBackgroundLaunch: Bool)
    }

    private static func installLocked(dependencies: Dependencies) -> InstallResult {
      if let monitor = lock.withLock({ _monitor }) {
        return .alreadyInstalled(monitor)
      }

      // Outside `lock` because reading and writing the launch history does I/O. Only one install
      // gets here, so the history is still updated once per process, and the monitor isn't
      // observing yet, so no activation can read the launch type before it's set.
      let classifier = dependencies.classifier
      let classification = classifier.begin()
      // Installed after the app became active, so its launch can't be measured anymore and the
      // next activation is a resume.
      let isAppActive = dependencies.isAppActive()
      // The process was already alive when the user first brought the app to the foreground, so
      // that activation is a resume.
      let isBackgroundLaunch = dependencies.isBackgroundLaunch()
      let monitor = ActivationMonitor(
        dependencies: dependencies,
        classifier: classifier,
        classification: classification,
        tracker: ActivationTracker(isAppActive: isAppActive, isBackgroundLaunch: isBackgroundLaunch)
      )
      monitor.start()
      lock.withLock { _monitor = monitor }
      return .installed(isAppActive: isAppActive, isBackgroundLaunch: isBackgroundLaunch)
    }

    /// Removes the observers and clears all state so the next install starts over. Tests only.
    package static func reset() {
      installLock.withLock {
        let monitor = lock.withLock {
          defer { _monitor = nil }
          return _monitor
        }
        monitor?.stop()
      }
    }
  }

  // An extension, so `Dependencies` keeps its memberwise initializer.
  extension AppLaunchRuntime.Dependencies {
    package init(configuration: AppLaunchInstrumentationConfiguration,
                 makeClassifier: @escaping @Sendable (Self) -> LaunchClassifier,
                 makeRecorder: @escaping @Sendable (Self) -> AppStartRecording) {
      self.init(makeClassifier: makeClassifier, makeRecorder: makeRecorder)
      self.configuration = configuration
    }
  }
#endif

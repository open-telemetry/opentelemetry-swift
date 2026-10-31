/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  import InstrumentationCommon
  import OpenTelemetryApi

  /// Records each activation of the app, as Apple defines it, as an `AppStart` span that ends at
  /// the first frame displayed after the app becomes active:
  ///
  /// - `cold`: a launch the system is unlikely to have cached: the app's first launch, or its
  ///   first launch after a reboot or an app update. Starts at process start.
  /// - `warm`: any other launch. Starts at process start.
  /// - `resume`: the app's process was still alive. Starts when the app begins returning to the
  ///   foreground.
  ///
  /// Launches that iOS prewarmed are marked with `start.active_prewarmed` and start when app code
  /// first ran. On macOS only launches are recorded, and they end when the app becomes active.
  ///
  /// Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS. On watchOS this does nothing.
  public class AppLaunchInstrumentation: Instrumentation {
    // Matches the instrumentation scope used by OpenTelemetry Android.
    static let instrumentationScope = "io.opentelemetry.lifecycle"
    static let spanName = "AppStart"

    typealias LaunchType = AppLaunchInstrumentationConfiguration.LaunchType

    struct Dependencies: Sendable {
      var notificationCenter: NotificationCenter = .default
      var didBecomeActiveNotification: Notification.Name = defaultDidBecomeActiveNotification
      var willEnterForegroundNotification: Notification.Name? = defaultWillEnterForegroundNotification
      var didEnterBackgroundNotification: Notification.Name? = defaultDidEnterBackgroundNotification
      var sceneWillConnectNotification: Notification.Name? = defaultSceneWillConnectNotification
      var firstFrameReader: FirstFrameReader? = defaultFirstFrameReader
      var processStartTime: @Sendable () -> Date? = readProcessStartTime
      var earliestAppCodeTime: @Sendable () -> Date? = readEarliestAppCodeTime
      var isActivePrewarm: @Sendable () -> Bool = readIsActivePrewarm
      var isAppActive: @Sendable () -> Bool = readIsAppActive
      var isBackgroundLaunch: @Sendable () -> Bool = readIsBackgroundLaunch
      var configuration = AppLaunchInstrumentationConfiguration()
      var currentLaunchContext: @Sendable () -> LaunchContext? = readCurrentLaunchContext
      var launchHistory: LaunchHistory = UserDefaultsLaunchHistory()
      var now: @Sendable () -> Date = Date.init
      // Runs the block once the main thread has finished handling the current event.
      var afterCurrentEvent: @Sendable (@escaping @Sendable () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }

      var launchTypeClassifier: LaunchTypeClassifier {
        InferredLaunchTypeClassifier(currentLaunchContext: currentLaunchContext, launchHistory: launchHistory)
      }
    }

    /// Whether the instrumentation is installed and observing app activations.
    public static var isInstalled: Bool {
      lock.withLock { _monitor != nil }
    }

    // Guards `_monitor`.
    private static let lock = NSLock()
    // Held for a whole install, so a concurrent install returns only once the first one is
    // observing activations. Notification callbacks never take it.
    private static let installLock = NSLock()
    nonisolated(unsafe) private static var _monitor: ActivationMonitor?

    /// Installs the instrumentation, the same as `install(configuration:)`. If it's already
    /// installed, `configuration` is ignored.
    public init(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      super.init(scope: Self.instrumentationScope)
      Self.install(configuration: configuration)
    }

    /// Starts observing app activations. Idempotent and thread-safe. Call it as early as
    /// possible, before the app first becomes active, so the launch is recorded. If it's called on
    /// the main thread while the app is active, the launch isn't recorded and the next activation
    /// is recorded as `resume`. Called later than that while the app is inactive or in the
    /// background, the next activation is recorded as a launch from process start, because a
    /// scene-based app is also in the background state during a normal launch.
    ///
    /// Only the first call takes effect. A later call with a different configuration is ignored
    /// and reported through `OpenTelemetry.instance.feedbackHandler`.
    public static func install(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      install(dependencies: Dependencies(configuration: configuration))
    }

    static func install(dependencies: Dependencies) {
      // Logged outside `installLock`, because the feedback handler is the app's code and could
      // call `install` again.
      switch installLock.withLock({ installLocked(dependencies: dependencies) }) {
      case let .alreadyInstalled(configuration):
        if configuration != dependencies.configuration {
          InternalLogger.error("AppLaunchInstrumentation is already installed, so the new configuration is ignored.")
        }
      case let .installed(launchType, isAppActive, isBackgroundLaunch):
        InternalLogger.info(
          "AppLaunchInstrumentation installed: launch type \(launchType), app active \(isAppActive), background launch \(isBackgroundLaunch)."
        )
      }
    }

    private enum InstallResult {
      case alreadyInstalled(AppLaunchInstrumentationConfiguration)
      case installed(LaunchType, isAppActive: Bool, isBackgroundLaunch: Bool)
    }

    private static func installLocked(dependencies: Dependencies) -> InstallResult {
      if let monitor = lock.withLock({ _monitor }) {
        return .alreadyInstalled(monitor.configuration)
      }

      // Outside `lock` because reading and writing the launch history does I/O. Only one install
      // gets here, so the history is still updated once per process, and the monitor isn't
      // observing yet, so no activation can read the launch type before it's set.
      let launchType = dependencies.launchTypeClassifier.classify()
      // Installed after the app became active, so its launch can't be measured anymore and the
      // next activation is a resume.
      let isAppActive = dependencies.isAppActive()
      // The process was already alive when the user first brought the app to the foreground, so
      // that activation is a resume.
      let isBackgroundLaunch = dependencies.isBackgroundLaunch()
      let monitor = ActivationMonitor(
        dependencies: dependencies,
        tracker: ActivationTracker(launchType: launchType, isAppActive: isAppActive, isBackgroundLaunch: isBackgroundLaunch)
      )
      monitor.start()
      lock.withLock { _monitor = monitor }
      return .installed(launchType, isAppActive: isAppActive, isBackgroundLaunch: isBackgroundLaunch)
    }

    /// Removes the observers and clears all state so the next install starts over. Tests only.
    static func reset() {
      installLock.withLock {
        let monitor = lock.withLock {
          defer { _monitor = nil }
          return _monitor
        }
        monitor?.stop()
      }
    }
  }
#else
  import InstrumentationCommon

  /// Does nothing, because this platform isn't supported, so code shared with a supported platform
  /// doesn't need its own check. Supported on iOS, iPadOS, tvOS, visionOS, Mac Catalyst and macOS.
  public class AppLaunchInstrumentation: Instrumentation {
    static let instrumentationScope = "io.opentelemetry.lifecycle"

    /// Always `false`.
    public static var isInstalled: Bool { false }

    public init(configuration: AppLaunchInstrumentationConfiguration = .init()) {
      super.init(scope: Self.instrumentationScope)
    }

    public static func install(configuration: AppLaunchInstrumentationConfiguration = .init()) {}
  }
#endif

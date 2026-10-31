/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  import InstrumentationCommon
  import InstrumentationSemanticConventions
  import OpenTelemetryApi
  #if canImport(UIKit)
    import UIKit
  #else
    import AppKit
  #endif

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
  public class AppLaunchInstrumentation: Instrumentation {
    // Matches the instrumentation scope used by OpenTelemetry Android.
    static let instrumentationScope = "io.opentelemetry.lifecycle"
    static let spanName = "AppStart"

    typealias LaunchType = AppLaunchInstrumentationConfiguration.LaunchType
    typealias StartAttributes = FederatedSemanticConventions.Start

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
    }

    #if canImport(UIKit)
      static let defaultDidBecomeActiveNotification = UIApplication.didBecomeActiveNotification
      static let defaultWillEnterForegroundNotification: Notification.Name? = UIApplication.willEnterForegroundNotification
      static let defaultDidEnterBackgroundNotification: Notification.Name? = UIApplication.didEnterBackgroundNotification
      static let defaultSceneWillConnectNotification: Notification.Name? = UIScene.willConnectNotification
      static var defaultFirstFrameReader: FirstFrameReader? { DisplayLinkFirstFrameReader() }

      /// Whether the app is active, or `false` if that can't be read off the main thread.
      static func readIsAppActive() -> Bool {
        guard Thread.isMainThread else { return false }
        return MainActor.assumeIsolated {
          // `UIApplication.shared` is unavailable in app extensions, so look it up dynamically, as
          // Datadog does.
          let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication
          return application?.applicationState == .active
        }
      }
    #else
      static let defaultDidBecomeActiveNotification = NSApplication.didBecomeActiveNotification
      static let defaultWillEnterForegroundNotification: Notification.Name? = nil
      static let defaultDidEnterBackgroundNotification: Notification.Name? = nil
      static let defaultSceneWillConnectNotification: Notification.Name? = nil
      static var defaultFirstFrameReader: FirstFrameReader? { nil }

      /// Whether the app is active, or `false` if that can't be read off the main thread.
      static func readIsAppActive() -> Bool {
        guard Thread.isMainThread else { return false }
        return MainActor.assumeIsolated {
          // `NSApp` is nil until the app creates its `NSApplication`, so this doesn't create one.
          let application: NSApplication? = NSApp
          return application?.isActive ?? false
        }
      }
    #endif

    /// Whether the instrumentation is installed and observing app activations.
    public static var isInstalled: Bool {
      lock.withLock { !_observers.isEmpty }
    }

    // Guards every `_` property below, so install, the notification callbacks and reset each see
    // and change them in one step.
    private static let lock = NSLock()
    // Held for a whole install, so a concurrent install returns only once the first one is
    // observing activations. Notification callbacks never take it.
    private static let installLock = NSLock()
    nonisolated(unsafe) private static var _dependencies: Dependencies?
    nonisolated(unsafe) private static var _observers: [NSObjectProtocol] = []
    nonisolated(unsafe) private static var _launchType = LaunchType.cold
    nonisolated(unsafe) private static var _hasHandledLaunch = false
    nonisolated(unsafe) private static var _isInForeground = true
    // When the resume that hasn't reached `didBecomeActive` yet began.
    nonisolated(unsafe) private static var _pendingResumeStart: Date?
    // When a scene connected while the app was in the background, until the main thread finishes
    // handling that event.
    nonisolated(unsafe) private static var _sceneConnectTime: Date?
    // Whether the process's role says the system started it in the background, and it hasn't
    // entered the foreground or background since.
    nonisolated(unsafe) private static var _isUnconfirmedBackgroundLaunch = false
    // Incremented whenever the app enters the background, so a first frame read that started
    // before then doesn't record an activation that spans the time in the background.
    nonisolated(unsafe) private static var _backgroundCount = 0

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
      // Reported outside `installLock`, because the handler is the app's code and could call
      // `install` again.
      let installedConfiguration = installLock.withLock { installLocked(dependencies: dependencies) }
      if let installedConfiguration, installedConfiguration != dependencies.configuration {
        OpenTelemetry.instance.feedbackHandler?(
          "AppLaunchInstrumentation is already installed, so the new configuration is ignored."
        )
      }
    }

    /// Returns the installed configuration if the instrumentation was already installed.
    private static func installLocked(dependencies: Dependencies) -> AppLaunchInstrumentationConfiguration? {
      let installedConfiguration: AppLaunchInstrumentationConfiguration? = lock.withLock {
        if let installed = _dependencies {
          return installed.configuration
        }
        _dependencies = dependencies
        return nil
      }
      if let installedConfiguration {
        return installedConfiguration
      }

      // Outside `lock` because reading and writing the launch history does I/O. Only the install
      // that set `_dependencies` gets here, so the history is still updated once per process, and
      // the observers aren't registered yet, so no activation can read the launch type before it's
      // set.
      let launchType = classifyLaunch(dependencies)
      // Installed after the app became active, so its launch can't be measured anymore and the
      // next activation is a resume.
      let isAppActive = dependencies.isAppActive()
      // The process was already alive when the user first brought the app to the foreground, so
      // that activation is a resume.
      let isBackgroundLaunch = dependencies.isBackgroundLaunch()
      lock.withLock {
        _launchType = launchType
        _hasHandledLaunch = isAppActive || isBackgroundLaunch
        _isInForeground = isAppActive || !isBackgroundLaunch
        _isUnconfirmedBackgroundLaunch = isBackgroundLaunch && !isAppActive
      }

      // Registered outside `lock` because a notification posted on another thread can run the
      // block before `addObserver` returns, and the block takes `lock`. A nil queue runs the
      // block synchronously on the posting thread, which is the main thread for application
      // notifications, so the first frame read starts before the run loop commits that frame.
      let center = dependencies.notificationCenter
      func observe(_ name: Notification.Name?, _ handler: @escaping @Sendable () -> Void) -> NSObjectProtocol? {
        name.map { center.addObserver(forName: $0, object: nil, queue: nil) { _ in handler() } }
      }
      let observers = [
        observe(dependencies.didBecomeActiveNotification, appDidBecomeActive),
        observe(dependencies.willEnterForegroundNotification, appWillEnterForeground),
        observe(dependencies.didEnterBackgroundNotification, appDidEnterBackground),
        observe(dependencies.sceneWillConnectNotification, sceneWillConnect),
      ].compactMap { $0 }

      lock.withLock { _observers = observers }
      return nil
    }

    /// Removes the observers and clears all state so the next install starts over. Tests only.
    static func reset() {
      installLock.withLock {
        let (dependencies, observers): (Dependencies?, [NSObjectProtocol]) = lock.withLock {
          defer {
            _dependencies = nil
            _observers = []
            _launchType = .cold
            _hasHandledLaunch = false
            _isInForeground = true
            _pendingResumeStart = nil
            _sceneConnectTime = nil
            _isUnconfirmedBackgroundLaunch = false
            _backgroundCount += 1
          }
          return (_dependencies, _observers)
        }
        if let dependencies {
          observers.forEach(dependencies.notificationCenter.removeObserver)
        }
      }
    }

    /// A launch is warm when the device hasn't rebooted and the app hasn't been updated since the
    /// previous launch, so the system is likely to still have the app's code and data cached.
    private static func classifyLaunch(_ dependencies: Dependencies) -> LaunchType {
      guard let current = dependencies.currentLaunchContext(),
            let previous = dependencies.launchHistory.exchange(current),
            current.isSameState(as: previous) else { return .cold }
      return .warm
    }

    private static func sceneWillConnect() {
      let dependencies: Dependencies? = lock.withLock {
        // The system recreates a scene it discarded while the app was in the background before
        // the app enters the foreground, so a resume starts when that scene connects. A scene
        // connecting while the app is in the foreground, such as a second window on iPad, isn't
        // an activation, and during a launch the scene connection is part of the launch.
        guard let dependencies = _dependencies, _hasHandledLaunch, !_isInForeground else { return nil }
        _sceneConnectTime = dependencies.now()
        return dependencies
      }
      // UIKit connects a scene the user brings up and moves it to the foreground while handling
      // the same event. A scene the system connects in the background, for example after
      // launching the app in the background, stays there, so it doesn't start a resume. If UIKit
      // ever moved it to the foreground later, the resume would start at `willEnterForeground`.
      dependencies?.afterCurrentEvent {
        lock.withLock { _sceneConnectTime = nil }
      }
    }

    private static func appWillEnterForeground() {
      lock.withLock {
        guard let dependencies = _dependencies, _hasHandledLaunch else { return }
        _isInForeground = true
        _isUnconfirmedBackgroundLaunch = false
        if _pendingResumeStart == nil {
          _pendingResumeStart = _sceneConnectTime ?? dependencies.now()
        }
        _sceneConnectTime = nil
      }
    }

    private static func appDidEnterBackground() {
      lock.withLock {
        // Before the app first became active, this means the system launched it into the
        // background, or the user left before the launch finished. The process stays alive, so
        // the next activation is a resume.
        _hasHandledLaunch = true
        _isInForeground = false
        _isUnconfirmedBackgroundLaunch = false
        _pendingResumeStart = nil
        _sceneConnectTime = nil
        _backgroundCount += 1
      }
    }

    private static func appDidBecomeActive() {
      enum Activation {
        case launch(type: LaunchType)
        case resume(start: Date)
      }
      let state: (Dependencies, Activation, backgroundCount: Int)? = lock.withLock {
        guard let dependencies = _dependencies else { return nil }
        // An app that really launched in the background enters the foreground before it becomes
        // active, so if it didn't, the role was wrong and this is the launch.
        if !_hasHandledLaunch || _isUnconfirmedBackgroundLaunch {
          _hasHandledLaunch = true
          _isInForeground = true
          _isUnconfirmedBackgroundLaunch = false
          return (dependencies, .launch(type: _launchType), _backgroundCount)
        }
        // Without a pending resume the app only lost input focus, for example to Control Center
        // or a system alert, and never left the foreground.
        guard let resumeStart = _pendingResumeStart else { return nil }
        _pendingResumeStart = nil
        return (dependencies, .resume(start: resumeStart), _backgroundCount)
      }
      guard let (dependencies, activation, backgroundCount) = state else { return }

      let launchType: LaunchType = switch activation {
      case let .launch(type): type
      case .resume: .resume
      }
      guard dependencies.configuration.launchTypes.contains(launchType) else { return }

      let didBecomeActiveTime = dependencies.now()
      // Read when the app becomes active, so a tracer provider registered after install is used.
      let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScope)

      let recordActivation: (Date) -> Void
      switch activation {
      case let .launch(type):
        guard let processStartTime = dependencies.processStartTime() else { return }
        recordActivation = { end in
          recordLaunch(tracer: tracer, type: type, processStartTime: processStartTime, end: end, dependencies: dependencies)
        }
      case let .resume(start):
        recordActivation = { end in
          tracer.spanBuilder(spanName: spanName)
            .setStartTime(time: start)
            .setAttribute(key: StartAttributes.type.rawValue, value: StartAttributes.TypeValues.resume.description)
            .startSpan()
            .end(time: end)
        }
      }

      guard let firstFrameReader = dependencies.firstFrameReader else {
        recordActivation(didBecomeActiveTime)
        return
      }
      firstFrameReader.readFirstFrame { firstFrameTime in
        // A display link pauses in the background, so if the app left the foreground before the
        // first frame, the frame it reports is from the next time the app returned.
        guard lock.withLock({ _backgroundCount == backgroundCount }) else { return }
        // A start never ends before the app became active, whatever the reader reports.
        recordActivation(max(firstFrameTime, didBecomeActiveTime))
      }
    }

    private static func recordLaunch(tracer: Tracer, type: LaunchType, processStartTime: Date, end: Date, dependencies: Dependencies) {
      let configuration = dependencies.configuration
      let isPrewarmed = dependencies.isActivePrewarm()
      if isPrewarmed, configuration.dropPrewarmed {
        return
      }
      // A prewarmed process started long before the user launched the app, so time the launch
      // from when app code first ran instead.
      let startTime = isPrewarmed ? dependencies.earliestAppCodeTime() ?? processStartTime : processStartTime
      // Too long for the user to have waited through all of it: a background launch that wasn't
      // detected, the prewarm ran app code, or the instrumentation was installed off the main
      // thread after the app first became active.
      if end.timeIntervalSince(startTime) > configuration.maxLaunchDuration {
        return
      }

      tracer.spanBuilder(spanName: spanName)
        .setStartTime(time: startTime)
        .setAttribute(key: StartAttributes.type.rawValue, value: type.startTypeValue.description)
        .setAttribute(key: StartAttributes.activePrewarmed.rawValue, value: isPrewarmed)
        .startSpan()
        .end(time: end)
    }
  }

  extension AppLaunchInstrumentationConfiguration.LaunchType {
    var startTypeValue: FederatedSemanticConventions.Start.TypeValues {
      switch self {
      case .cold: .cold
      case .warm: .warm
      case .resume: .resume
      }
    }
  }
#endif

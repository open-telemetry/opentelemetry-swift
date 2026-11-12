/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation

  /// How much UI a resume had to rebuild.
  package enum ResumeKind: Sendable {
    case hot
    case sceneReconnect
    case backgroundLaunched
  }

  /// A return to the foreground while the process was alive.
  package struct AppResume: Sendable {
    package var start: Date
    package var kind: ResumeKind
    package var sceneConnectStart: Date?
    package var backgroundDuration: TimeInterval?
    /// The process's page-ins when the resume started, to diff against its end.
    package var pageInsAtStart: Int?
  }

  /// A time the app became active, and what kind of start that was.
  enum Activation {
    case launch(sceneConnectStart: Date?)
    case resume(AppResume)
  }

  /// Turns the app's lifecycle events into activations. It holds no lock and reads no clock, so its
  /// owner serializes the calls and passes the time in.
  struct ActivationTracker {
    private var hasHandledLaunch: Bool
    private var isInForeground: Bool
    // The resume that hasn't reached `didBecomeActive` yet.
    private var pendingResume: AppResume?
    private var hasBecomeActive: Bool
    private var lastBackgroundTime: Date?
    // When the launch's first scene connected.
    private var launchSceneConnectTime: Date?
    // When a scene connected while the app was in the background, until the main thread finishes
    // handling that event.
    private var sceneConnectTime: Date?
    // Whether the process's role says the system started it in the background, and it hasn't
    // entered the foreground or background since.
    private var isUnconfirmedBackgroundLaunch: Bool
    // Whether the process's role said the system started the app in the background, kept for the
    // whole process so a resume before the first activation can tell a background launch from a
    // launch the user left.
    private let isBackgroundLaunch: Bool
    // Incremented whenever the app enters the background, so a first frame read that started
    // before then doesn't record an activation that spans the time in the background.
    private(set) var backgroundCount = 0

    init(isAppActive: Bool, isBackgroundLaunch: Bool) {
      self.isBackgroundLaunch = isBackgroundLaunch
      hasHandledLaunch = isAppActive || isBackgroundLaunch
      hasBecomeActive = isAppActive
      isInForeground = isAppActive || !isBackgroundLaunch
      isUnconfirmedBackgroundLaunch = isBackgroundLaunch && !isAppActive
    }

    /// Returns whether the time was kept, so it must be cleared once the event has been handled.
    mutating func sceneWillConnect(at time: Date) -> Bool {
      if !hasBecomeActive, launchSceneConnectTime == nil {
        launchSceneConnectTime = time
      }
      // The system recreates a scene it discarded while the app was in the background before
      // the app enters the foreground, so a resume starts when that scene connects. A scene
      // connecting while the app is in the foreground, such as a second window on iPad, isn't
      // an activation, and during a launch the scene connection is part of the launch.
      guard hasHandledLaunch, !isInForeground else { return false }
      sceneConnectTime = time
      return true
    }

    mutating func sceneConnectionEventFinished() {
      sceneConnectTime = nil
    }

    mutating func willEnterForeground(at time: Date, pageIns: Int?) {
      guard hasHandledLaunch else { return }
      isInForeground = true
      isUnconfirmedBackgroundLaunch = false
      if pendingResume == nil {
        let start = sceneConnectTime ?? time
        // `background_launched` is only for a process the system started in the background. The
        // other way to reach a resume before the first activation is a launch the user left before
        // its first frame, which did enter the background, so its UI is built and a page baseline
        // was taken: that's an ordinary resume.
        let isSystemBackgroundLaunch = !hasBecomeActive && isBackgroundLaunch
        let kind: ResumeKind = isSystemBackgroundLaunch ? .backgroundLaunched : sceneConnectTime != nil ? .sceneReconnect : .hot
        pendingResume = AppResume(start: start,
                                  kind: kind,
                                  sceneConnectStart: sceneConnectTime,
                                  backgroundDuration: lastBackgroundTime.map(start.timeIntervalSince),
                                  pageInsAtStart: pageIns)
      }
      sceneConnectTime = nil
    }

    /// Returns whether this happened before the first activation, so no launch will be recorded.
    mutating func didEnterBackground(at time: Date) -> Bool {
      let isBeforeFirstActivation = !hasHandledLaunch
      // Before the app first became active, this means the system launched it into the
      // background, or the user left before the launch finished. The process stays alive, so
      // the next activation is a resume.
      hasHandledLaunch = true
      isInForeground = false
      isUnconfirmedBackgroundLaunch = false
      pendingResume = nil
      sceneConnectTime = nil
      lastBackgroundTime = time
      backgroundCount += 1
      return isBeforeFirstActivation
    }

    /// Returns the activation this started, or `nil` if it isn't one.
    mutating func didBecomeActive() -> Activation? {
      // An app that really launched in the background enters the foreground before it becomes
      // active, so if it didn't, the role was wrong and this is the launch.
      if !hasHandledLaunch || isUnconfirmedBackgroundLaunch {
        hasHandledLaunch = true
        isInForeground = true
        isUnconfirmedBackgroundLaunch = false
        hasBecomeActive = true
        return .launch(sceneConnectStart: launchSceneConnectTime)
      }
      // Without a pending resume the app only lost input focus, for example to Control Center
      // or a system alert, and never left the foreground.
      guard let resume = pendingResume else { return nil }
      pendingResume = nil
      hasBecomeActive = true
      return .resume(resume)
    }
  }
#endif

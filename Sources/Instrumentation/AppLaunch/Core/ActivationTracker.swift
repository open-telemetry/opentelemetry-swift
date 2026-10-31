/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation

  /// A time the app became active, and what kind of start that was.
  enum Activation {
    case launch
    case resume(start: Date)
  }

  /// Turns the app's lifecycle events into activations. It holds no lock and reads no clock, so its
  /// owner serializes the calls and passes the time in.
  struct ActivationTracker {
    private var hasHandledLaunch: Bool
    private var isInForeground: Bool
    // When the resume that hasn't reached `didBecomeActive` yet began.
    private var pendingResumeStart: Date?
    // When a scene connected while the app was in the background, until the main thread finishes
    // handling that event.
    private var sceneConnectTime: Date?
    // Whether the process's role says the system started it in the background, and it hasn't
    // entered the foreground or background since.
    private var isUnconfirmedBackgroundLaunch: Bool
    // Incremented whenever the app enters the background, so a first frame read that started
    // before then doesn't record an activation that spans the time in the background.
    private(set) var backgroundCount = 0

    init(isAppActive: Bool, isBackgroundLaunch: Bool) {
      hasHandledLaunch = isAppActive || isBackgroundLaunch
      isInForeground = isAppActive || !isBackgroundLaunch
      isUnconfirmedBackgroundLaunch = isBackgroundLaunch && !isAppActive
    }

    /// Returns whether the time was kept, so it must be cleared once the event has been handled.
    mutating func sceneWillConnect(at time: Date) -> Bool {
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

    mutating func willEnterForeground(at time: Date) {
      guard hasHandledLaunch else { return }
      isInForeground = true
      isUnconfirmedBackgroundLaunch = false
      if pendingResumeStart == nil {
        pendingResumeStart = sceneConnectTime ?? time
      }
      sceneConnectTime = nil
    }

    /// Returns whether this happened before the first activation, so no launch will be recorded.
    mutating func didEnterBackground() -> Bool {
      let isBeforeFirstActivation = !hasHandledLaunch
      // Before the app first became active, this means the system launched it into the
      // background, or the user left before the launch finished. The process stays alive, so
      // the next activation is a resume.
      hasHandledLaunch = true
      isInForeground = false
      isUnconfirmedBackgroundLaunch = false
      pendingResumeStart = nil
      sceneConnectTime = nil
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
        return .launch
      }
      // Without a pending resume the app only lost input focus, for example to Control Center
      // or a system alert, and never left the foreground.
      guard let resumeStart = pendingResumeStart else { return nil }
      pendingResumeStart = nil
      return .resume(start: resumeStart)
    }
  }
#endif

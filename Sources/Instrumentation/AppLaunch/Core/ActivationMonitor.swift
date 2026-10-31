/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  import OpenTelemetryApi

  /// Feeds the app's lifecycle notifications to an `ActivationTracker`, and hands each activation to
  /// an `AppStartRecorder` when its first frame is displayed.
  final class ActivationMonitor: @unchecked Sendable {
    let classifier: LaunchClassifier
    private let dependencies: AppLaunchRuntime.Dependencies
    private let classification: @Sendable () -> LaunchClassification
    private let recorder: AppStartRecorder
    // Guards every `_` property below.
    private let lock = NSLock()
    private var _tracker: ActivationTracker
    private var _observers: [NSObjectProtocol] = []
    private var _isStopped = false

    var configuration: AppLaunchInstrumentationConfiguration { dependencies.configuration }

    init(dependencies: AppLaunchRuntime.Dependencies,
         classifier: LaunchClassifier,
         classification: @escaping @Sendable () -> LaunchClassification,
         tracker: ActivationTracker) {
      self.dependencies = dependencies
      self.classifier = classifier
      self.classification = classification
      recorder = AppStartRecorder(dependencies: dependencies)
      _tracker = tracker
    }

    func start() {
      // Registered outside `lock` because a notification posted on another thread can run the
      // block before `addObserver` returns, and the block takes `lock`. A nil queue runs the
      // block synchronously on the posting thread, which is the main thread for application
      // notifications, so the first frame read starts before the run loop commits that frame.
      let center = dependencies.notificationCenter
      func observe(_ name: Notification.Name?, _ handler: @escaping @Sendable () -> Void) -> NSObjectProtocol? {
        name.map { center.addObserver(forName: $0, object: nil, queue: nil) { _ in handler() } }
      }
      let observers = [
        observe(dependencies.didBecomeActiveNotification) { [self] in appDidBecomeActive() },
        observe(dependencies.willEnterForegroundNotification) { [self] in appWillEnterForeground() },
        observe(dependencies.didEnterBackgroundNotification) { [self] in appDidEnterBackground() },
        observe(dependencies.sceneWillConnectNotification) { [self] in sceneWillConnect() },
      ].compactMap { $0 }

      lock.withLock { _observers = observers }
    }

    func stop() {
      let observers: [NSObjectProtocol] = lock.withLock {
        defer {
          _observers = []
          _isStopped = true
        }
        return _observers
      }
      observers.forEach(dependencies.notificationCenter.removeObserver)
    }

    private func sceneWillConnect() {
      let didKeepTime = lock.withLock { _tracker.sceneWillConnect(at: dependencies.now()) }
      guard didKeepTime else { return }
      // UIKit connects a scene the user brings up and moves it to the foreground while handling
      // the same event. A scene the system connects in the background, for example after
      // launching the app in the background, stays there, so it doesn't start a resume. If UIKit
      // ever moved it to the foreground later, the resume would start at `willEnterForeground`.
      dependencies.afterCurrentEvent { [self] in
        lock.withLock { _tracker.sceneConnectionEventFinished() }
      }
    }

    private func appWillEnterForeground() {
      lock.withLock { _tracker.willEnterForeground(at: dependencies.now()) }
    }

    private func appDidEnterBackground() {
      let isBeforeFirstActivation = lock.withLock { _tracker.didEnterBackground() }
      if isBeforeFirstActivation {
        InternalLogger.debug("AppLaunchInstrumentation: no launch recorded, because the app entered the background before it became active. The next activation is a resume.")
      }
    }

    private func appDidBecomeActive() {
      let state: (Activation, backgroundCount: Int)? = lock.withLock {
        guard !_isStopped, let activation = _tracker.didBecomeActive() else { return nil }
        return (activation, _tracker.backgroundCount)
      }
      guard let (activation, backgroundCount) = state else { return }

      let didBecomeActiveTime = dependencies.now()
      let start: AppStart = switch activation {
      case .launch: .launch(classification())
      case let .resume(start): .resume(start: start)
      }
      guard let record = recorder.prepare(start) else { return }

      guard let firstFrameReader = dependencies.firstFrameReader else {
        record(didBecomeActiveTime)
        return
      }
      firstFrameReader.readFirstFrame { [self] firstFrameTime in
        // A display link pauses in the background, so if the app left the foreground before the
        // first frame, the frame it reports is from the next time the app returned.
        guard lock.withLock({ !_isStopped && _tracker.backgroundCount == backgroundCount }) else {
          InternalLogger.debug("AppLaunchInstrumentation: dropped a \(start.launchType) start, because the app entered the background before the first frame.")
          return
        }
        // A start never ends before the app became active, whatever the reader reports.
        record(max(firstFrameTime, didBecomeActiveTime))
      }
    }
  }
#endif

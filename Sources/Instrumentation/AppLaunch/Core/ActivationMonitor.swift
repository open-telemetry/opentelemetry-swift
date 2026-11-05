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
    private let recorder: AppStartRecording
    // Guards every `_` property below.
    private let lock = NSLock()
    private var _tracker: ActivationTracker
    private var _observers: [NSObjectProtocol] = []
    private var _isStopped = false
    private var _didFinishLaunchingTime: Date?
    // Records the start that's waiting for its first frame as abandoned.
    private var _abandon: ((AppStartEnd) -> Void)?

    var configuration: AppLaunchInstrumentationConfiguration { dependencies.configuration }

    init(dependencies: AppLaunchRuntime.Dependencies,
         classifier: LaunchClassifier,
         classification: @escaping @Sendable () -> LaunchClassification,
         tracker: ActivationTracker) {
      self.dependencies = dependencies
      self.classifier = classifier
      self.classification = classification
      recorder = dependencies.recorder
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
        observe(dependencies.didFinishLaunchingNotification) { [self] in appDidFinishLaunching() },
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

    private func appDidFinishLaunching() {
      let time = dependencies.now()
      lock.withLock { _didFinishLaunchingTime = time }
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
      // Read outside the lock, because it's a `task_info` call.
      let time = dependencies.now()
      let pageIns = dependencies.readPageIns()
      lock.withLock { _tracker.willEnterForeground(at: time, pageIns: pageIns) }
    }

    private func appDidEnterBackground() {
      let time = dependencies.now()
      let (isBeforeFirstActivation, abandon) = lock.withLock {
        defer { _abandon = nil }
        return (_tracker.didEnterBackground(at: time), _abandon)
      }
      abandon?(.abandoned(time))
      // Taken here rather than when the app returns, because it's one `mincore` call per sampled
      // page and that would land inside the window the resume is measured over.
      dependencies.samplePagesAtBackground()
      if isBeforeFirstActivation {
        InternalLogger.debug("no launch recorded, because the app entered the background before it became active. The next activation is a resume.")
      }
    }

    private func appDidBecomeActive() {
      let state: (Activation, backgroundCount: Int, didFinishLaunchingTime: Date?)? = lock.withLock {
        guard !_isStopped, let activation = _tracker.didBecomeActive() else { return nil }
        return (activation, _tracker.backgroundCount, _didFinishLaunchingTime)
      }
      guard let (activation, backgroundCount, didFinishLaunchingTime) = state else { return }

      let didBecomeActiveTime = dependencies.now()
      let start: AppStart
      switch activation {
      case let .launch(sceneConnectStart):
        // The tracker above hands out one launch, but a process can hold more than one monitor
        // after a `reset`, and the process launched once. Taken before the classification is read,
        // because reading it compares the launch's page sample, which describes that one launch.
        guard AppLaunchRuntime.takeLaunchRecord() else {
          InternalLogger.debug("dropped a launch, because this process has already recorded one.")
          return
        }
        start = .launch(classification(), AppLaunchMarks(didFinishLaunchingEnd: didFinishLaunchingTime, sceneConnectStart: sceneConnectStart))
      case let .resume(resume):
        start = .resume(resume)
      }
      guard let record = recorder.prepare(start) else { return }

      guard let firstFrameReader = dependencies.firstFrameReader else {
        record(.firstFrame(didBecomeActiveTime))
        return
      }
      lock.withLock { _abandon = record }
      firstFrameReader.readFirstFrame { [self] firstFrameTime in
        // A display link pauses in the background, so if the app left the foreground before the
        // first frame, the frame it reports is from the next time the app returned.
        guard lock.withLock({ !_isStopped && _tracker.backgroundCount == backgroundCount }) else {
          InternalLogger.debug("dropped a \(start.launchType) start, because the app entered the background before the first frame.")
          return
        }
        // A start never ends before the app became active, whatever the reader reports.
        lock.withLock { _abandon = nil }
        record(.firstFrame(max(firstFrameTime, didBecomeActiveTime)))
      }
    }
  }
#endif

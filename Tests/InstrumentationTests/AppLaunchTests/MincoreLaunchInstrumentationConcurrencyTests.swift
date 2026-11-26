/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  @testable import AppLaunchInstrumentationCore
  @testable import MincoreLaunchInstrumentation
  import Foundation
  import SharedTestUtils
  import XCTest

  /// Stress tests for install, activation and reset. They only run under Thread Sanitizer (or
  /// with `OTEL_CONCURRENCY_TESTS=1`).
  extension MincoreLaunchInstrumentationTests {
    func testInstallUnderContentionObservesOnce() throws {
      try ConcurrencyTesting.skipUnlessEnabled()
      let dependencies = makeDependencies()
      let notInstalledAfterReturn = ConcurrentCounter()

      ConcurrencyTesting.stress(iterations: 50) { _, _ in
        MincoreLaunchInstrumentation.install(dependencies: dependencies)
        // Once any install call has returned, the instrumentation must report itself installed.
        if !MincoreLaunchInstrumentation.isInstalled {
          notInstalledAfterReturn.increment()
        }
      }

      notificationCenter.post(name: didBecomeActive, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(notInstalledAfterReturn.value, 0, "install() returned before the instrumentation was marked installed")
      XCTAssertEqual(firstFrameReader.readCount, 1, "the activation observer must be registered exactly once")
      XCTAssertEqual(launchHistory.exchangeCount, 1, "the launch history must be updated exactly once")
      XCTAssertEqual(rootSpans().count, 1)
    }

    func testConcurrentActivationsRecordOneColdStart() throws {
      try ConcurrencyTesting.skipUnlessEnabled()
      install()
      let center = notificationCenter!
      let name = didBecomeActive

      ConcurrencyTesting.stress(iterations: 50) { _, _ in
        center.post(name: name, object: nil)
      }
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertEqual(firstFrameReader.readCount, 1)
      XCTAssertEqual(rootSpans().count, 1)
    }

    func testInstallRacingActivationRecordsAtMostOneColdStart() throws {
      try ConcurrencyTesting.skipUnlessEnabled()
      let dependencies = makeDependencies()
      let center = notificationCenter!
      let name = didBecomeActive

      let install: @Sendable () -> Void = {
        for _ in 0 ..< 50 { MincoreLaunchInstrumentation.install(dependencies: dependencies) }
      }
      let activate: @Sendable () -> Void = {
        for _ in 0 ..< 50 { center.post(name: name, object: nil) }
      }
      ConcurrencyTesting.concurrently(Array(repeating: install, count: 4) + Array(repeating: activate, count: 4))

      // Once installed, a later activation must not record a second cold start.
      center.post(name: name, object: nil)
      firstFrameReader.displayFrame(at: firstFrame)

      XCTAssertTrue(MincoreLaunchInstrumentation.isInstalled)
      XCTAssertEqual(firstFrameReader.readCount, 1)
      XCTAssertEqual(rootSpans().count, 1)
    }

    func testResetRacingActivationLeavesNoObserverBehind() throws {
      try ConcurrencyTesting.skipUnlessEnabled()
      let dependencies = makeDependencies()
      let center = notificationCenter!
      let name = didBecomeActive

      ConcurrencyTesting.stress(iterations: 50) { thread, _ in
        switch thread % 3 {
        case 0:
          MincoreLaunchInstrumentation.install(dependencies: dependencies)
        case 1:
          center.post(name: name, object: nil)
        default:
          AppLaunchRuntime.reset()
        }
      }

      // After a final reset, no observer registered during the race may still record.
      AppLaunchRuntime.reset()
      let readsBefore = firstFrameReader.readCount
      center.post(name: name, object: nil)

      XCTAssertEqual(firstFrameReader.readCount, readsBefore)
    }

    func testConcurrentLifecycleNotificationsRecordOneSpanPerStart() throws {
      try ConcurrencyTesting.skipUnlessEnabled()
      install()
      let center = notificationCenter!
      let names = [didBecomeActive, willEnterForeground, didEnterBackground, sceneWillConnect]

      ConcurrencyTesting.stress(iterations: 50) { thread, iteration in
        center.post(name: names[(thread + iteration) % names.count], object: nil)
      }
      firstFrameReader.displayFrame(at: firstFrame)

      // A start that reached a first frame comes from a read, and a read interrupted by a
      // background event is dropped, so there can't be more completed starts than reads. A start
      // the app left before its first frame is recorded as abandoned, with no read behind it.
      let outcomes = rootSpans().map { $0.attributes["app.start.outcome"] ?? $0.attributes["app.resume.outcome"] }
      XCTAssertLessThanOrEqual(outcomes.filter { $0 == .string("completed") }.count, firstFrameReader.readCount)
      XCTAssertFalse(outcomes.contains(nil), "every root records an outcome")

      // The process launched once, however many activations raced.
      XCTAssertLessThanOrEqual(rootSpans().filter { $0.name == "app.start" }.count, 1)

      // The race above can legitimately record nothing at all, so it carries no liveness
      // assertion. The tracker hands out one launch, which loses the publication check to any
      // background event that lands while the start is being prepared, and every later
      // activation returns nil unless a resume is pending. Liveness is checked below instead, on
      // a quiet state machine.
      //
      // `didEnterBackground` takes no guard, so it leaves the tracker in a known state whatever
      // the race left behind: in the background, with no pending resume and the launch handled.
      center.post(name: didEnterBackground, object: nil)
      let readsBefore = firstFrameReader.readCount
      let resumesBefore = rootSpans().filter { $0.name == "app.resume" }.count

      // From there `willEnterForeground` must leave a pending resume, and `didBecomeActive` must
      // hand it out and read a first frame, with nothing racing the publication check.
      center.post(name: willEnterForeground, object: nil)
      center.post(name: didBecomeActive, object: nil)
      XCTAssertEqual(firstFrameReader.readCount, readsBefore + 1, "an uncontended resume must read a first frame")

      firstFrameReader.displayFrame(at: firstFrame)
      XCTAssertEqual(rootSpans().filter { $0.name == "app.resume" }.count, resumesBefore + 1,
                     "an uncontended resume must record exactly one span")
    }
  }
#endif

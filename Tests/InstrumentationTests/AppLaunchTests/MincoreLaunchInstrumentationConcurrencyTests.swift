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

      // Every span comes from a first frame read, and reads interrupted by a background event are
      // dropped, so there can't be more spans than reads.
      XCTAssertGreaterThanOrEqual(firstFrameReader.readCount, 1)
      XCTAssertLessThanOrEqual(rootSpans().count, firstFrameReader.readCount)
    }
  }
#endif

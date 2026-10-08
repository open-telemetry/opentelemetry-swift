/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import Crash
@testable import Sessions
import SharedTestUtils
import XCTest

/// Stress tests for install and crash-context updates. They only run under Thread Sanitizer (or
/// with `OTEL_CONCURRENCY_TESTS=1`).
///
/// KSCrash can be installed once per process and rejects a second install, so these live on
/// `KSCrashInstrumentationTests` and are named to sort after `testInstallMethod`, which needs to
/// see the process before its first install. In a full run they therefore race the
/// already-installed path; run on their own (`--filter`) they race the first install.
extension KSCrashInstrumentationTests {
  private func observerCount() -> Int {
    KSCrashInstrumentation.queue.sync { KSCrashInstrumentation.observers.count }
  }

  func testInstallUnderContentionInstallsOnce() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    let wasInstalled = KSCrashInstrumentation.isInstalled
    let observersBefore = observerCount()
    let notInstalledAfterReturn = ConcurrentCounter()

    ConcurrencyTesting.stress(iterations: 50) { thread, _ in
      switch thread % 4 {
      case 0:
        KSCrashInstrumentation.install(config: Self.testConfig())
        // Once any install call has returned, the instrumentation must report itself installed.
        if !KSCrashInstrumentation.isInstalled {
          notInstalledAfterReturn.increment()
        }
      case 1:
        // A different configuration must not reinstall or register a second observer.
        let config = Self.testConfig()
        config.maxStackTraceBytes = 1024
        KSCrashInstrumentation.install(config: config)
      case 2:
        _ = KSCrashInstrumentation.isInstalled
        _ = KSCrashInstrumentation.maxStackTraceBytes
      default:
        KSCrashInstrumentation.maxStackTraceBytes = KSCrashInstrumentation.maxStackTraceBytes
      }
    }
    // Drain the work install() dispatched (crash context, stored crashes).
    KSCrashInstrumentation.queue.sync {}

    XCTAssertTrue(KSCrashInstrumentation.isInstalled)
    XCTAssertEqual(notInstalledAfterReturn.value, 0, "install() returned before the instrumentation was marked installed")
    XCTAssertEqual(observerCount() - observersBefore, wasInstalled ? 0 : 1,
                   "the session observer must be registered exactly once across all install calls")
  }

  func testInstallUnderContentionWithSessionRollovers() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    let manager = try SessionManager(persistence: InMemorySessionPersistence())

    // Install calls race session starts, whose notifications write the crash context on `queue`.
    let install: @Sendable () -> Void = { KSCrashInstrumentation.install(config: Self.testConfig()) }
    let rollOver: @Sendable () -> Void = { for _ in 0 ..< 50 { manager.resetSession() } }
    ConcurrencyTesting.concurrently(Array(repeating: install, count: 4) + Array(repeating: rollOver, count: 4))

    // Once install has registered the observer, a session start must reach the crash context.
    let latest = manager.resetSession()
    KSCrashInstrumentation.queue.sync {}

    let userInfo = KSCrashInstrumentation.reporter.userInfo as? [String: String]
    XCTAssertEqual(userInfo?[SemanticConventions.Session.id.rawValue], latest.id)
    XCTAssertEqual(userInfo?[SemanticConventions.Session.previousId.rawValue], latest.previousId)
  }
}

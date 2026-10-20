/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import Sessions
import SharedTestUtils
import XCTest

/// Stress tests for session management. They only run under Thread Sanitizer
/// (or with `OTEL_CONCURRENCY_TESTS=1`).
final class SessionsConcurrencyTests: XCTestCase {
  private let sessionIdKey = SemanticConventions.Session.id.rawValue

  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    SessionStore.teardown()
  }

  override func tearDown() {
    guard ConcurrencyTesting.isEnabled else { return }
    SessionStore.teardown()
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
  }

  private func makeManager(sessionTimeout: TimeInterval = 3600) -> SessionManager {
    SessionManager(configuration: SessionConfig(sessionTimeout: sessionTimeout, restorePersistedSession: false))
  }

  // MARK: - SessionManager

  func testGetAndPeekFromManyThreadsShareOneSession() {
    let manager = makeManager()
    let ids = ConcurrentCollector<String>()

    ConcurrencyTesting.stress { thread, _ in
      if thread == 0 {
        if let session = manager.peekSession() {
          ids.append(session.id)
        }
      } else {
        ids.append(manager.getSession().id)
      }
    }

    XCTAssertEqual(Set(ids.values).count, 1)
  }

  func testSessionRotatesOnEveryCallUnderContention() {
    // A zero timeout expires the session immediately, so every call takes the
    // "start new session" path: event queueing, notifications and store saves.
    let manager = makeManager(sessionTimeout: 0)
    let ids = ConcurrentCollector<String>()
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { _, _ in
      ids.append(manager.getSession().id)
      _ = manager.peekSession()
    }

    XCTAssertEqual(ids.count, threads * iterations)
    XCTAssertEqual(Set(ids.values).count, threads * iterations)
  }

  // MARK: - SessionStore

  func testStoreSaveAndLoadFromManyThreads() {
    ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 50) { thread, iteration in
      let session = Session(id: "\(thread)-\(iteration)",
                            expireTime: Date(timeIntervalSinceNow: 60),
                            previousId: iteration == 0 ? nil : "\(thread)-\(iteration - 1)",
                            startTime: Date())
      if thread.isMultiple(of: 2) {
        SessionStore.saveImmediately(session: session)
      } else {
        SessionStore.scheduleSave(session: session)
      }
      _ = SessionStore.load()
    }

    XCTAssertNotNil(SessionStore.load())
  }

  // MARK: - Processors

  func testSharedSpanProcessorFromManyThreads() {
    let manager = makeManager()
    let processor = UncheckedSendable(SessionSpanProcessor(sessionManager: manager))
    let expectedId = manager.getSession().id
    let mismatches = ConcurrentCounter()
    let sessionIdKey = self.sessionIdKey

    ConcurrencyTesting.stress { _, _ in
      let span = MockReadableSpan()
      processor.value.onStart(parentContext: nil, span: span)
      processor.value.onEnd(span: span)
      if span.capturedAttributes[sessionIdKey] != .string(expectedId) {
        mismatches.increment()
      }
    }

    XCTAssertEqual(mismatches.value, 0)
  }

  func testSpanProcessorInsideTracerProviderFromManyThreads() {
    let manager = makeManager()
    let provider = TracerProviderSdk(spanProcessors: [SessionSpanProcessor(sessionManager: manager)])
    let tracer = UncheckedSendable(provider.get(instrumentationName: "stress"))
    let expectedId = manager.getSession().id
    let mismatches = ConcurrentCounter()
    let sessionIdKey = self.sessionIdKey

    ConcurrencyTesting.stress { thread, _ in
      let span = tracer.value.spanBuilder(spanName: "span-\(thread)").startSpan()
      if let readable = span as? ReadableSpan, readable.toSpanData().attributes[sessionIdKey] != .string(expectedId) {
        mismatches.increment()
      }
      span.end()
    }

    XCTAssertEqual(mismatches.value, 0)
  }

  func testSharedLogRecordProcessorFromManyThreads() {
    let manager = makeManager()
    let next = MockLogRecordProcessor()
    let processor = UncheckedSendable(SessionLogRecordProcessor(nextProcessor: next, sessionManager: manager))
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      processor.value.onEmit(logRecord: TelemetryFixtures.logRecord(body: "log-\(thread)-\(iteration)"))
      if iteration == 0 {
        _ = processor.value.forceFlush(explicitTimeout: nil)
      }
    }

    let records = next.receivedLogRecords
    XCTAssertEqual(records.count, threads * iterations)
    XCTAssertTrue(records.allSatisfy { $0.attributes[sessionIdKey] != nil })
  }

  // MARK: - Session events

  func testInstallRacesQueuedSessionEvents() {
    let exporter = InMemoryLogRecordExporter()
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [SimpleLogRecordProcessor(logRecordExporter: exporter)])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    SessionEventInstrumentation.queue.removeAll()
    SessionEventInstrumentation.isApplied = false
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      if thread == 0, iteration == 10 {
        SessionEventInstrumentation.install()
      }
      let session = Session(id: "\(thread)-\(iteration)",
                            expireTime: Date(timeIntervalSinceNow: 60),
                            previousId: nil,
                            startTime: Date(timeIntervalSinceNow: -1))
      SessionEventInstrumentation.addSession(session: session, eventType: iteration.isMultiple(of: 2) ? .start : .end)
    }

    XCTAssertTrue(SessionEventInstrumentation.isApplied)
    XCTAssertTrue(SessionEventInstrumentation.queue.isEmpty)
    XCTAssertGreaterThan(exporter.getFinishedLogRecords().count, 0)
  }

  // MARK: - Provider

  func testRegisterRacesGetInstance() {
    let managers = UncheckedSendable((0 ..< 4).map { _ in makeManager() })
    let initial = ObjectIdentifier(SessionManagerProvider.getInstance())
    let seen = ConcurrentCollector<ObjectIdentifier>()

    ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 50) { thread, iteration in
      if thread < 4, iteration.isMultiple(of: 10) {
        SessionManagerProvider.register(sessionManager: managers.value[thread])
      }
      seen.append(ObjectIdentifier(SessionManagerProvider.getInstance()))
    }

    // Every observed instance is either the one present before the test or
    // one of the managers registered during it.
    let allowed = Set(managers.value.map { ObjectIdentifier($0) }).union([initial])
    XCTAssertTrue(Set(seen.values).isSubset(of: allowed))
    SessionManagerProvider.register(sessionManager: SessionManager())
  }
}

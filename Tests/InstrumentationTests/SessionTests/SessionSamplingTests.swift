import XCTest
@testable import Sessions

final class SessionSamplingTests: XCTestCase {
  func testNewSessionMakesOneDecisionSharedAcrossSignalAccess() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )

    let session = manager.getSession()
    let traceDecision = manager.samplingDecision()
    let logDecision = manager.samplingDecision()
    let metricDecision = manager.samplingDecision()

    XCTAssertEqual(session.samplingDecision, .notSampled)
    XCTAssertEqual(traceDecision, session.samplingDecision)
    XCTAssertEqual(logDecision, session.samplingDecision)
    XCTAssertEqual(metricDecision, session.samplingDecision)
    XCTAssertEqual(sampler.callCount, 1)
    XCTAssertEqual(sampler.sessionIds, [session.id])
  }

  func testRestoredSessionKeepsPersistedDecision() throws {
    let persistence = TestSessionPersistence()
    let firstSampler = TestSessionSampler(decisions: [.notSampled])
    let firstManager = try SessionManager(
      configuration: SessionConfig(sampler: firstSampler),
      persistence: persistence
    )
    let firstSession = firstManager.getSession()
    XCTAssertEqual(firstSampler.callCount, 1)

    let restoreSampler = TestSessionSampler(decisions: [.sampled])
    let restoredManager = try SessionManager(
      configuration: SessionConfig(sampler: restoreSampler),
      persistence: persistence
    )

    XCTAssertEqual(restoredManager.peekSession(), firstSession)
    XCTAssertEqual(restoredManager.peekSession()?.samplingDecision, .notSampled)
    XCTAssertEqual(restoreSampler.callCount, 0)
  }

  func testExpiredSessionGetsOneNewDecision() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled, .sampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sessionTimeout: 0, sampler: sampler),
      persistence: TestSessionPersistence()
    )

    let expiredSession = manager.getSession()
    let replacementSession = manager.getSession()

    XCTAssertNotEqual(replacementSession.id, expiredSession.id)
    XCTAssertEqual(replacementSession.previousId, expiredSession.id)
    XCTAssertEqual(expiredSession.samplingDecision, .notSampled)
    XCTAssertEqual(replacementSession.samplingDecision, .sampled)
    XCTAssertEqual(sampler.callCount, 2)
  }

  func testActivityKeepsCurrentDecision() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let session = manager.getSession()

    let activeSession = manager.recordActivity()

    XCTAssertEqual(activeSession.id, session.id)
    XCTAssertEqual(activeSession.samplingDecision, .notSampled)
    XCTAssertEqual(sampler.callCount, 1)
  }

  func testDecisionAccessDoesNotRecordActivity() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let session = manager.getSessionForAttribution()
    Thread.sleep(forTimeInterval: 0.01)

    let decision = manager.samplingDecision()

    XCTAssertEqual(decision, .notSampled)
    XCTAssertEqual(manager.peekSession()?.expireTime, session.expireTime)
    XCTAssertEqual(sampler.callCount, 1)
  }

  func testResetGetsOneNewDecisionAndPersistsIt() throws {
    SessionEventInstrumentation.queue = []
    SessionEventInstrumentation.isApplied = false
    defer {
      SessionEventInstrumentation.queue = []
      SessionEventInstrumentation.isApplied = false
    }
    let persistence = TestSessionPersistence()
    let sampler = TestSessionSampler(decisions: [.sampled, .notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: persistence
    )
    let firstSession = manager.getSession()
    SessionEventInstrumentation.queue = []
    let replacementSession = manager.resetSession()
    let record = try decodeCurrentRecord(from: persistence)

    XCTAssertEqual(firstSession.samplingDecision, .sampled)
    XCTAssertEqual(replacementSession.samplingDecision, .notSampled)
    XCTAssertEqual(replacementSession.previousId, firstSession.id)
    XCTAssertEqual(record.session.value, replacementSession)
    XCTAssertEqual(sampler.callCount, 2)
    XCTAssertEqual(SessionEventInstrumentation.queue.count, 2)
    XCTAssertEqual(SessionEventInstrumentation.queue.first?.session.samplingDecision, .sampled)
  }

  func testVersionOneRecordGetsOneDecisionAndIsUpgraded() throws {
    let persistence = TestSessionPersistence()
    let versionOneSession = VersionOneSession(
      id: "version-one-session",
      expireTime: Date(timeIntervalSinceNow: 1800),
      previousId: "previous-session",
      startTime: Date(timeIntervalSinceNow: -300),
      sessionTimeout: 1800,
      maxLifetime: 7200
    )
    try persistence.write(PropertyListEncoder().encode(
      VersionOneRecord(version: 1, session: versionOneSession)
    ))
    let sampler = TestSessionSampler(decisions: [.notSampled])

    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: persistence
    )
    let restoredSession = try XCTUnwrap(manager.peekSession())
    let upgradedRecord = try decodeCurrentRecord(from: persistence)

    XCTAssertEqual(restoredSession.id, versionOneSession.id)
    XCTAssertEqual(restoredSession.samplingDecision, .notSampled)
    XCTAssertEqual(sampler.callCount, 1)
    XCTAssertEqual(upgradedRecord.version, PersistedSessionRecord.currentVersion)
    XCTAssertEqual(upgradedRecord.session.value, restoredSession)

    let secondSampler = TestSessionSampler(decisions: [.sampled])
    let secondManager = try SessionManager(
      configuration: SessionConfig(sampler: secondSampler),
      persistence: persistence
    )
    XCTAssertEqual(secondManager.peekSession()?.samplingDecision, .notSampled)
    XCTAssertEqual(secondSampler.callCount, 0)
  }

  func testLegacyKeysGetOneDecisionAndAreUpgraded() throws {
    let suiteName = "io.opentelemetry.session-sampling-tests.\(UUID().uuidString)"
    let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { userDefaults.removePersistentDomain(forName: suiteName) }
    userDefaults.removePersistentDomain(forName: suiteName)
    let persistence = UserDefaultsSessionPersistence(
      userDefaults: userDefaults,
      namespace: "legacy-session"
    )
    userDefaults.set("legacy-session-id", forKey: persistence.idKey)
    userDefaults.set(Date(timeIntervalSinceNow: 1800), forKey: persistence.expireTimeKey)
    userDefaults.set(Date(timeIntervalSinceNow: -300), forKey: persistence.startTimeKey)
    userDefaults.set(1800.0, forKey: persistence.sessionTimeoutKey)
    let sampler = TestSessionSampler(decisions: [.notSampled])

    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: persistence
    )
    let restoredSession = try XCTUnwrap(manager.peekSession())
    let data = try XCTUnwrap(persistence.read())
    let upgradedRecord = try PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)

    XCTAssertEqual(restoredSession.id, "legacy-session-id")
    XCTAssertEqual(restoredSession.samplingDecision, .notSampled)
    XCTAssertEqual(sampler.callCount, 1)
    XCTAssertEqual(upgradedRecord.session.value, restoredSession)
    XCTAssertNil(userDefaults.object(forKey: persistence.idKey))
  }

  func testConcurrentFirstAccessSamplesOnce() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let resultLock = NSLock()
    nonisolated(unsafe) var sessions: [Session] = []

    DispatchQueue.concurrentPerform(iterations: 50) { _ in
      let session = manager.getSession()
      resultLock.withLock { sessions.append(session) }
    }

    XCTAssertEqual(Set(sessions.map(\.id)).count, 1)
    XCTAssertEqual(Set(sessions.map(\.samplingDecision)), [.notSampled])
    XCTAssertEqual(sampler.callCount, 1)
  }

  func testSamplerRunsOutsideSessionStateLock() throws {
    let sampler = BlockingSessionSampler()
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let creationFinished = expectation(description: "Session creation finished")
    DispatchQueue.global().async {
      manager.getSessionForAttribution()
      creationFinished.fulfill()
    }
    XCTAssertEqual(sampler.didStart.wait(timeout: .now() + 1), .success)

    let peekFinished = expectation(description: "Read-only access remained available")
    DispatchQueue.global().async {
      _ = manager.peekSession()
      peekFinished.fulfill()
    }
    wait(for: [peekFinished], timeout: 0.5)

    sampler.allowCompletion.signal()
    wait(for: [creationFinished], timeout: 1)
  }

  private func decodeCurrentRecord(from persistence: TestSessionPersistence) throws -> PersistedSessionRecord {
    let data = try XCTUnwrap(persistence.read())
    return try PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)
  }
}

private struct VersionOneRecord: Codable {
  let version: Int
  let session: VersionOneSession
}

private struct VersionOneSession: Codable {
  let id: String
  let expireTime: Date
  let previousId: String?
  let startTime: Date
  let sessionTimeout: TimeInterval
  let maxLifetime: TimeInterval?
}

private final class BlockingSessionSampler: SessionSampler, @unchecked Sendable {
  let didStart = DispatchSemaphore(value: 0)
  let allowCompletion = DispatchSemaphore(value: 0)

  func samplingDecision(for sessionId: String) -> SessionSamplingDecision {
    didStart.signal()
    _ = allowCompletion.wait(timeout: .now() + 5)
    return .sampled
  }
}

import XCTest
import OpenTelemetryApi
@testable import Sessions
@testable import OpenTelemetrySdk

final class SessionSamplingTests: XCTestCase {
  func testSamplingDecisionWireContract() {
    XCTAssertEqual(PersistedSessionRecord.currentVersion, 2)
    XCTAssertEqual(SessionSamplingDecision.sampled.rawValue, "sampled")
    XCTAssertEqual(SessionSamplingDecision.notSampled.rawValue, "notSampled")
    XCTAssertTrue(SessionSamplingDecision.sampled.isSampled)
    XCTAssertFalse(SessionSamplingDecision.notSampled.isSampled)
  }

  func testBuiltInSamplersReturnTheirNamedDecision() {
    XCTAssertEqual(AlwaysOnSessionSampler().samplingDecision(for: "session"), .sampled)
    XCTAssertEqual(AlwaysOffSessionSampler().samplingDecision(for: "session"), .notSampled)
  }

  func testNewSessionMakesOneDecisionSharedAcrossSignalAccess() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )

    let session = manager.getSession()
    let traceDecision = try XCTUnwrap(manager.samplingDecision())
    let logDecision = try XCTUnwrap(manager.samplingDecision())
    let metricDecision = try XCTUnwrap(manager.samplingDecision())

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

  func testRepeatedAccessKeepsCurrentDecision() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let session = manager.getSession()

    let activeSession = manager.getSession()

    XCTAssertEqual(activeSession.id, session.id)
    XCTAssertEqual(activeSession.samplingDecision, .notSampled)
    XCTAssertEqual(sampler.callCount, 1)
  }

  func testDecisionAccessRecordsActivity() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let session = manager.getSession()
    Thread.sleep(forTimeInterval: 0.01)

    let decision = try XCTUnwrap(manager.samplingDecision())

    XCTAssertEqual(decision, .notSampled)
    XCTAssertGreaterThan(manager.peekSession()?.expireTime ?? .distantPast, session.expireTime)
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
    XCTAssertTrue(persistence.write(Self.versionOneFixture))
    let sampler = TestSessionSampler(decisions: [.notSampled])

    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: persistence
    )
    let restoredSession = try XCTUnwrap(manager.peekSession())
    let upgradedRecord = try decodeCurrentRecord(from: persistence)

    XCTAssertEqual(restoredSession.id, "version-one-session")
    XCTAssertEqual(restoredSession.previousId, "previous-session")
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

  func testCurrentRecordFixtureRestoresWithoutResampling() throws {
    let persistence = TestSessionPersistence()
    XCTAssertTrue(persistence.write(Self.versionTwoFixture))
    let sampler = TestSessionSampler(decisions: [.sampled])

    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: persistence
    )
    let restoredSession = try XCTUnwrap(manager.peekSession())

    XCTAssertEqual(restoredSession.id, "version-two-session")
    XCTAssertEqual(restoredSession.previousId, "previous-session")
    XCTAssertEqual(restoredSession.samplingDecision, .notSampled)
    XCTAssertEqual(sampler.callCount, 0)
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

  func testConcurrentSignalWaitsForInitialSamplingDecision() throws {
    let sampler = BlockingSessionSampler()
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let creationFinished = expectation(description: "Session creation finished")
    DispatchQueue.global().async {
      manager.getSession()
      creationFinished.fulfill()
    }
    XCTAssertEqual(sampler.didStart.wait(timeout: .now() + 1), .success)

    let peekFinished = expectation(description: "Read-only access remained available")
    DispatchQueue.global().async {
      _ = manager.peekSession()
      peekFinished.fulfill()
    }
    wait(for: [peekFinished], timeout: 0.5)

    let signalFinished = DispatchSemaphore(value: 0)
    let span = MockReadableSpan()
    DispatchQueue.global().async {
      SessionSpanProcessor(sessionManager: manager).onStart(parentContext: nil, span: span)
      signalFinished.signal()
    }
    XCTAssertEqual(signalFinished.wait(timeout: .now() + 0.1), .timedOut)

    sampler.allowCompletion.signal()
    wait(for: [creationFinished], timeout: 1)
    XCTAssertEqual(signalFinished.wait(timeout: .now() + 1), .success)
    XCTAssertEqual(
      span.capturedAttributes[SemanticConventions.Session.id.rawValue],
      manager.peekSession().map { AttributeValue.string($0.id) }
    )
  }

  func testSamplerCanEmitLogDuringInitialCreation() throws {
    let sampler = CallbackSessionSampler()
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let nextProcessor = MockLogRecordProcessor()
    let processor = SessionLogRecordProcessor(nextProcessor: nextProcessor, sessionManager: manager)
    sampler.onSample = { processor.onEmit(logRecord: Self.testLogRecord) }
    defer { sampler.onSample = nil }

    let session = manager.getSession()

    XCTAssertEqual(nextProcessor.receivedLogRecords.count, 1)
    XCTAssertNil(nextProcessor.receivedLogRecords[0].attributes[SemanticConventions.Session.id.rawValue])
    processor.onEmit(logRecord: Self.testLogRecord)
    XCTAssertEqual(
      nextProcessor.receivedLogRecords[1].attributes[SemanticConventions.Session.id.rawValue],
      AttributeValue.string(session.id)
    )
  }

  func testSamplerCanReadDecisionDuringInitialCreationWithoutRecursing() throws {
    let sampler = CallbackSessionSampler()
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    var decisionDuringSampling: SessionSamplingDecision?
    sampler.onSample = { decisionDuringSampling = manager.samplingDecision() }
    defer { sampler.onSample = nil }

    let session = manager.getSession()

    XCTAssertNil(decisionDuringSampling)
    XCTAssertEqual(manager.samplingDecision(), session.samplingDecision)
  }

  func testSamplerCanEmitLogDuringExpiryRotation() throws {
    let sampler = CallbackSessionSampler()
    let manager = try SessionManager(
      configuration: SessionConfig(sessionTimeout: 0, sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let firstSession = manager.getSession()
    let nextProcessor = MockLogRecordProcessor()
    let processor = SessionLogRecordProcessor(nextProcessor: nextProcessor, sessionManager: manager)
    sampler.onSample = { processor.onEmit(logRecord: Self.testLogRecord) }
    defer { sampler.onSample = nil }

    let replacement = manager.getSession()

    XCTAssertEqual(replacement.previousId, firstSession.id)
    XCTAssertEqual(nextProcessor.receivedLogRecords.count, 1)
    XCTAssertNil(nextProcessor.receivedLogRecords[0].attributes[SemanticConventions.Session.id.rawValue])
  }

  func testResetSamplerRunsOutsideSessionMutationLock() throws {
    let sampler = CallbackSessionSampler()
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let firstSession = manager.getSession()
    sampler.onSample = {
      let accessFinished = DispatchSemaphore(value: 0)
      DispatchQueue.global().async {
        _ = manager.getSession()
        accessFinished.signal()
      }
      XCTAssertEqual(accessFinished.wait(timeout: .now() + 0.5), .success)
    }

    let replacement = manager.resetSession()

    XCTAssertEqual(replacement.previousId, firstSession.id)
  }

  func testSlowResetSamplerDoesNotBlockLiveAttribution() throws {
    let sampler = BlockingAfterFirstSessionSampler()
    let manager = try SessionManager(
      configuration: SessionConfig(sampler: sampler),
      persistence: TestSessionPersistence()
    )
    let firstSession = manager.getSession()
    let resetFinished = expectation(description: "Reset finished")
    DispatchQueue.global().async {
      _ = manager.resetSession()
      resetFinished.fulfill()
    }
    XCTAssertEqual(sampler.didStartBlocking.wait(timeout: .now() + 1), .success)

    let attributionFinished = expectation(description: "Live access stayed available")
    let resultLock = NSLock()
    nonisolated(unsafe) var attributedSession: Session?
    DispatchQueue.global().async {
      let session = manager.getSession()
      resultLock.withLock { attributedSession = session }
      attributionFinished.fulfill()
    }
    wait(for: [attributionFinished], timeout: 0.5)
    XCTAssertEqual(resultLock.withLock { attributedSession?.id }, firstSession.id)

    sampler.allowCompletion.signal()
    wait(for: [resetFinished], timeout: 1)
  }

  private func decodeCurrentRecord(from persistence: TestSessionPersistence) throws -> PersistedSessionRecord {
    let data = try XCTUnwrap(persistence.read())
    return try PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)
  }

  private static let testLogRecord = ReadableLogRecord(
    resource: Resource(attributes: [:]),
    instrumentationScopeInfo: InstrumentationScopeInfo(),
    timestamp: Date(),
    observedTimestamp: Date(),
    spanContext: nil,
    severity: .info,
    body: AttributeValue.string("sampler log"),
    attributes: [:]
  )

  private static let versionOneFixture = Data("""
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>version</key><integer>1</integer>
    <key>session</key><dict>
      <key>id</key><string>version-one-session</string>
      <key>expireTime</key><date>2099-01-01T00:30:00Z</date>
      <key>previousId</key><string>previous-session</string>
      <key>startTime</key><date>2099-01-01T00:00:00Z</date>
      <key>sessionTimeout</key><real>1800</real>
      <key>maxLifetime</key><real>7200</real>
    </dict>
  </dict></plist>
  """.utf8)

  private static let versionTwoFixture = Data("""
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>version</key><integer>2</integer>
    <key>session</key><dict>
      <key>id</key><string>version-two-session</string>
      <key>expireTime</key><date>2099-01-01T00:30:00Z</date>
      <key>previousId</key><string>previous-session</string>
      <key>startTime</key><date>2099-01-01T00:00:00Z</date>
      <key>sessionTimeout</key><real>1800</real>
      <key>maxLifetime</key><real>7200</real>
      <key>samplingDecision</key><string>notSampled</string>
    </dict>
  </dict></plist>
  """.utf8)
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

private final class CallbackSessionSampler: SessionSampler, @unchecked Sendable {
  private let lock = NSLock()
  private var callback: (() -> Void)?

  var onSample: (() -> Void)? {
    get { lock.withLock { callback } }
    set { lock.withLock { callback = newValue } }
  }

  func samplingDecision(for sessionId: String) -> SessionSamplingDecision {
    let callback = lock.withLock { self.callback }
    callback?()
    return .sampled
  }
}

private final class BlockingAfterFirstSessionSampler: SessionSampler, @unchecked Sendable {
  let didStartBlocking = DispatchSemaphore(value: 0)
  let allowCompletion = DispatchSemaphore(value: 0)
  private let lock = NSLock()
  private var callCount = 0

  func samplingDecision(for sessionId: String) -> SessionSamplingDecision {
    let shouldBlock = lock.withLock {
      callCount += 1
      return callCount > 1
    }
    if shouldBlock {
      didStartBlocking.signal()
      _ = allowCompletion.wait(timeout: .now() + 5)
    }
    return .sampled
  }
}

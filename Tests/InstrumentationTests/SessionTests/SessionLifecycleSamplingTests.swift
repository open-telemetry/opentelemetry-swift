import XCTest
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import Sessions

private let decisionAttribute = SessionConstants.sessionSamplingDecision

final class SessionLifecycleSamplingTests: XCTestCase {
  private var allEvents: InMemoryLogRecordExporter!
  private var sampledEvents: InMemoryLogRecordExporter!

  override func setUp() {
    super.setUp()
    SessionStore.teardown()
    SessionEventInstrumentation.queue.removeAll()
    SessionEventInstrumentation.isApplied = false
    allEvents = InMemoryLogRecordExporter()
    sampledEvents = InMemoryLogRecordExporter()
  }

  override func tearDown() {
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
    SessionEventInstrumentation.queue.removeAll()
    SessionEventInstrumentation.isApplied = false
    SessionStore.teardown()
    super.tearDown()
  }

  func testResetFromSampledToNotSampledKeepsOriginalEventDecisions() throws {
    try checkReset(decisions: [.sampled, .notSampled], queued: false)
  }

  func testResetFromNotSampledToSampledKeepsOriginalEventDecisions() throws {
    try checkReset(decisions: [.notSampled, .sampled], queued: false)
  }

  func testQueuedEventsKeepDecisionsAfterReset() throws {
    try checkReset(decisions: [.sampled, .notSampled], queued: true)
  }

  func testRestartFromSampledToNotSampledKeepsPersistedEndDecision() throws {
    try checkRestart(previousDecision: .sampled, nextDecision: .notSampled, restoreExpired: false)
  }

  func testRestartFromNotSampledToSampledKeepsPersistedEndDecision() throws {
    try checkRestart(previousDecision: .notSampled, nextDecision: .sampled, restoreExpired: false)
  }

  func testExpiredRestoredSessionKeepsPersistedEndDecision() throws {
    try checkRestart(previousDecision: .sampled, nextDecision: .notSampled, restoreExpired: true)
  }

  func testEndOnlyFilteringDoesNotCreateAnotherSession() throws {
    let sampler = TestSessionSampler(decisions: [.notSampled])
    let manager = try SessionManager(configuration: SessionConfig(sampler: sampler),
                                     persistence: TestSessionPersistence())
    installLogPipeline(manager: manager)
    SessionEventInstrumentation.install()
    let session = manager.getSession()

    manager.endSession()

    assertEvents([(session, SessionConstants.sessionStartEvent), (session, SessionConstants.sessionEndEvent)])
    XCTAssertNil(manager.peekSession())
    XCTAssertEqual(sampler.callCount, 1)
  }

  private func checkReset(decisions: [SessionSamplingDecision], queued: Bool) throws {
    let sampler = TestSessionSampler(decisions: decisions)
    let manager = try SessionManager(configuration: SessionConfig(sampler: sampler),
                                     persistence: TestSessionPersistence())
    installLogPipeline(manager: manager)
    if !queued {
      SessionEventInstrumentation.install()
    }
    let first = manager.getSession()
    let second = manager.resetSession()
    if queued {
      XCTAssertTrue(allEvents.getFinishedLogRecords().isEmpty)
      SessionEventInstrumentation.install()
    }

    assertEvents([(first, SessionConstants.sessionStartEvent),
                  (first, SessionConstants.sessionEndEvent),
                  (second, SessionConstants.sessionStartEvent)])
    XCTAssertEqual(manager.peekSession()?.id, second.id)
    XCTAssertEqual(sampler.callCount, 2)
  }

  private func checkRestart(previousDecision: SessionSamplingDecision,
                            nextDecision: SessionSamplingDecision,
                            restoreExpired: Bool) throws {
    let persistence = TestSessionPersistence()
    let previous = Session(id: "previous-run", expireTime: Date(timeIntervalSinceNow: restoreExpired ? -1 : 60),
                           previousId: "older-run", startTime: Date(timeIntervalSinceNow: -120),
                           sessionTimeout: 60, maxLifetime: nil, samplingDecision: previousDecision)
    SessionStore(persistence: persistence).saveImmediately(session: previous)
    let sampler = TestSessionSampler(decisions: [nextDecision])
    let manager = try SessionManager(
      configuration: SessionConfig(restorePersistedSession: restoreExpired, sampler: sampler),
      persistence: persistence
    )
    XCTAssertEqual(sampler.callCount, 0, "Restoring a saved decision must not resample it")
    installLogPipeline(manager: manager)
    SessionEventInstrumentation.install()

    let current = manager.getSession()

    assertEvents([(previous, SessionConstants.sessionEndEvent), (current, SessionConstants.sessionStartEvent)])
    XCTAssertEqual(current.previousId, previous.id)
    XCTAssertEqual(current.samplingDecision, nextDecision)
    XCTAssertEqual(sampler.callCount, 1)
  }

  private func installLogPipeline(manager: SessionManager) {
    let filter = LifecycleSamplingFilter(allEvents: allEvents, sampledEvents: sampledEvents)
    let provider = LoggerProviderBuilder()
      .with(processors: [SessionLogRecordProcessor(nextProcessor: filter, sessionManager: manager)])
      .build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: provider)
  }

  private func assertEvents(_ expected: [(Session, String)], file: StaticString = #filePath, line: UInt = #line) {
    let records = allEvents.getFinishedLogRecords()
    XCTAssertEqual(records.count, expected.count, file: file, line: line)
    for (record, (session, eventName)) in zip(records, expected) {
      XCTAssertEqual(record.eventName, eventName, file: file, line: line)
      XCTAssertEqual(record.attributes[SemanticConventions.Session.id.rawValue], .string(session.id), file: file, line: line)
      XCTAssertEqual(record.attributes[SemanticConventions.Session.previousId.rawValue],
                     session.previousId.map(AttributeValue.string), file: file, line: line)
      XCTAssertEqual(record.attributes[decisionAttribute], .string(session.samplingDecision.rawValue), file: file, line: line)
    }
    let sampled = expected.filter(\.0.samplingDecision.isSampled)
    let exported = sampledEvents.getFinishedLogRecords()
    XCTAssertEqual(exported.map(\.eventName), sampled.map(\.1), file: file, line: line)
    XCTAssertEqual(exported.map { $0.attributes[SemanticConventions.Session.id.rawValue] },
                   sampled.map { .string($0.0.id) }, file: file, line: line)
  }
}

/// A log integration filters lifecycle events using their own decision, never the current manager.
private final class LifecycleSamplingFilter: LogRecordProcessor {
  private let allEvents: InMemoryLogRecordExporter
  private let sampledEvents: InMemoryLogRecordExporter

  init(allEvents: InMemoryLogRecordExporter, sampledEvents: InMemoryLogRecordExporter) {
    self.allEvents = allEvents
    self.sampledEvents = sampledEvents
  }

  func onEmit(logRecord: ReadableLogRecord) {
    _ = allEvents.export(logRecords: [logRecord])
    guard case let .string(value)? = logRecord.attributes[decisionAttribute],
          let decision = SessionSamplingDecision(rawValue: value), decision.isSampled else { return }
    _ = sampledEvents.export(logRecords: [logRecord])
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    allEvents.shutdown(explicitTimeout: explicitTimeout)
    sampledEvents.shutdown(explicitTimeout: explicitTimeout)
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    return sampledEvents.forceFlush(explicitTimeout: explicitTimeout)
  }
}

import XCTest
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import Sessions
import SharedTestUtils

final class SessionSamplingIntegrationTests: XCTestCase {
  override func setUp() {
    super.setUp()
    SessionStore.teardown()
    SessionEventInstrumentation.queue.removeAll()
    SessionEventInstrumentation.isApplied = false
  }

  override func tearDown() {
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
    SessionEventInstrumentation.queue.removeAll()
    SessionEventInstrumentation.isApplied = false
    SessionStore.teardown()
    super.tearDown()
  }

  func testTraceAndLogExportFollowSavedDecisionAfterRestart() throws {
    for sampled in [false, true] {
      let persistence = TestSessionPersistence()
      let decision: SessionSamplingDecision = sampled ? .sampled : .notSampled
      let original = try manager([decision], persistence: persistence).getSession()
      let restored = try manager([sampled ? .notSampled : .sampled], persistence: persistence)
      let spans = SamplingSpanExporter()
      let traces = TracerProviderBuilder().with(sampler: SessionTraceSampler(sessionManager: restored))
        .add(spanProcessor: SimpleSpanProcessor(spanExporter: spans)).build()
      defer { traces.shutdown() }
      traces.get(instrumentationName: "test").spanBuilder(spanName: "operation").startSpan().end()
      traces.forceFlush()

      let logs = InMemoryLogRecordExporter()
      let processor = SessionSamplingLogRecordProcessor(
        nextProcessor: SimpleLogRecordProcessor(logRecordExporter: logs), sessionManager: restored
      )
      defer { _ = processor.shutdown() }
      let logger = LoggerProviderBuilder().with(processors: [processor]).build()
        .get(instrumentationScopeName: "test")
      logger.logRecordBuilder().setBody(.string("operation")).emit()

      XCTAssertEqual(spans.finished.count, sampled ? 1 : 0)
      XCTAssertEqual(logs.getFinishedLogRecords().count, sampled ? 1 : 0)
      if sampled {
        XCTAssertEqual(spans.finished.first?.attributes[SemanticConventions.Session.id.rawValue], .string(original.id))
        XCTAssertEqual(logs.getFinishedLogRecords().first?.attributes[SemanticConventions.Session.id.rawValue], .string(original.id))
      }
      XCTAssertEqual(restored.peekSession()?.samplingDecision, decision)
    }
  }

  func testResetBetweenSamplingAndSpanStartKeepsOriginalIdentity() throws {
    let sessions = try manager([.sampled, .notSampled])
    let original = sessions.getSession()
    let delegate = ResettingTraceSampler { sessions.resetSession() }
    let spans = SamplingSpanExporter()
    let provider = TracerProviderBuilder()
      .with(sampler: SessionTraceSampler(sessionManager: sessions, delegate: delegate))
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: spans)).build()
    defer { provider.shutdown() }

    let span = provider.get(instrumentationName: "test").spanBuilder(spanName: "in-flight").startSpan()
    XCTAssertNotEqual(sessions.peekSession()?.id, original.id)
    span.end()
    provider.forceFlush()
    XCTAssertEqual(spans.finished.count, 1)
    XCTAssertEqual(spans.finished.first?.attributes[SemanticConventions.Session.id.rawValue], .string(original.id))
    XCTAssertEqual(spans.finished.first?.attributes[SessionConstants.sessionSamplingDecision], .string("sampled"))
  }

  func testParentAndSessionMustBothAllowSampling() throws {
    for sessionSampled in [false, true] {
      for parentSampled in [false, true] {
        for remote in [false, true] {
          let sessions = try manager([sessionSampled ? .sampled : .notSampled])
          let parent = remote
            ? SpanContext.createFromRemoteParent(traceId: TraceId.random(), spanId: SpanId.random(),
                                                 traceFlags: TraceFlags().settingIsSampled(parentSampled), traceState: TraceState())
            : SpanContext.create(traceId: TraceId.random(), spanId: SpanId.random(),
                                 traceFlags: TraceFlags().settingIsSampled(parentSampled), traceState: TraceState())
          let decision = SessionTraceSampler(sessionManager: sessions).shouldSample(
            parentContext: parent, traceId: parent.traceId, name: "child", kind: .client,
            attributes: [:], parentLinks: []
          )
          XCTAssertEqual(decision.isSampled, sessionSampled && parentSampled)
        }
      }
    }
  }

  func testDroppedChildDoesNotExportWithAnActiveSampledParent() throws {
    let sessions = try manager([.sampled, .notSampled])
    let spans = SamplingSpanExporter()
    let provider = TracerProviderBuilder().with(sampler: SessionTraceSampler(sessionManager: sessions))
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: spans)).build()
    defer { provider.shutdown() }
    let tracer = provider.get(instrumentationName: "test")
    let parent = tracer.spanBuilder(spanName: "parent").startSpan()
    OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
      sessions.resetSession()
      let child = tracer.spanBuilder(spanName: "dropped child").startSpan()
      XCTAssertFalse(child.isRecording)
      child.end()
    }
    parent.end()
    provider.forceFlush()
    XCTAssertEqual(spans.finished.map(\.name), ["parent"])
  }

  func testLimitedSpanAttributesNeverPickUpTheReplacementSession() throws {
    for limit in [0, 1, 2] {
      let sessions = try manager([.sampled, .notSampled])
      let original = sessions.getSession()
      let spans = SamplingSpanExporter()
      let provider = TracerProviderBuilder()
        .with(spanLimits: SpanLimits().settingAttributeCountLimit(UInt(limit)))
        .with(sampler: SessionTraceSampler(sessionManager: sessions, delegate: ResettingTraceSampler { sessions.resetSession() }))
        .add(spanProcessor: SimpleSpanProcessor(spanExporter: spans)).build()
      defer { provider.shutdown() }
      provider.get(instrumentationName: "test").spanBuilder(spanName: "limited").startSpan().end()
      provider.forceFlush()
      XCTAssertEqual(spans.finished.count, 1)
      if let id = spans.finished.first?.attributes[SemanticConventions.Session.id.rawValue] {
        XCTAssertEqual(id, .string(original.id))
      }
    }
  }

  func testHistoricalAndLifecycleLogsUseOriginalDecisionWithoutNewSession() throws {
    for decision in [SessionSamplingDecision.sampled, .notSampled] {
      let sessions = try manager([decision, decision == .sampled ? .notSampled : .sampled])
      let original = sessions.getSession()
      sessions.resetSession()
      sessions.endSession()
      let sink = MockLogRecordProcessor()
      let processor = SessionSamplingLogRecordProcessor(nextProcessor: sink, sessionManager: sessions)
      for eventName in [SessionConstants.sessionStartEvent, SessionConstants.sessionEndEvent, "app.crash"] {
        let record = ReadableLogRecord(
          resource: Resource(), instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
          timestamp: Date(), observedTimestamp: Date(), spanContext: nil, severity: .info,
          body: .string(eventName), attributes: original.samplingAttributes, eventName: eventName
        )
        processor.onEmit(logRecord: record)
      }
      XCTAssertNil(sessions.peekSession())
      XCTAssertEqual(sink.receivedLogRecords.count, decision.isSampled ? 3 : 0)
      for record in sink.receivedLogRecords {
        XCTAssertEqual(record.attributes, original.samplingAttributes)
      }
    }
  }

  func testUnknownHistoricalLogIsPreservedWithoutCurrentAttribution() throws {
    let sessions = try manager([.notSampled])
    let sink = MockLogRecordProcessor()
    let processor = SessionSamplingLogRecordProcessor(nextProcessor: sink, sessionManager: sessions)
    let record = TelemetryFixtures.logRecord(attributes: [SemanticConventions.Session.id.rawValue: .string("old-session")])
    processor.onEmit(logRecord: record)
    XCTAssertNil(sessions.peekSession())
    XCTAssertEqual(sink.receivedLogRecords.count, 1)
    XCTAssertEqual(sink.receivedLogRecords.first?.attributes, record.attributes)
    XCTAssertEqual(sink.receivedLogRecords.first?.timestamp, record.timestamp)
    XCTAssertEqual(sink.receivedLogRecords.first?.spanContext, record.spanContext)
  }

  func testCurrentAttributedLogWithoutSavedDecisionIsPreserved() throws {
    let sessions = try manager([.notSampled])
    let original = sessions.getSession()
    let sink = MockLogRecordProcessor()
    let processor = SessionSamplingLogRecordProcessor(nextProcessor: sink, sessionManager: sessions)
    processor.onEmit(logRecord: TelemetryFixtures.logRecord(attributes: [SemanticConventions.Session.id.rawValue: .string(original.id)]))
    XCTAssertEqual(sink.receivedLogRecords.count, 1)
    XCTAssertEqual(sessions.peekSession(), original)
  }

  func testMigratedSessionDoesNotResampleLegacyCrashLogs() throws {
    let persistence = TestSessionPersistence()
    XCTAssertTrue(persistence.write(SessionPersistenceFixtures.versionOne))
    let sessions = try manager([.notSampled], persistence: persistence)
    let restored = try XCTUnwrap(sessions.peekSession())
    XCTAssertEqual(restored.samplingDecision, .notSampled)
    let sink = MockLogRecordProcessor()
    let processor = SessionSamplingLogRecordProcessor(nextProcessor: sink, sessionManager: sessions)
    let record = TelemetryFixtures.logRecord(attributes: [SemanticConventions.Session.id.rawValue: .string(restored.id)])
    processor.onEmit(logRecord: record)
    XCTAssertEqual(sink.receivedLogRecords.count, 1)
    XCTAssertEqual(sink.receivedLogRecords.first?.attributes, record.attributes)
  }

  func testQueuedLifecycleEventsAndLinkedRestartUseTheirOwnDecisions() throws {
    let persistence = TestSessionPersistence()
    let originalManager = try manager([.sampled], persistence: persistence)
    let first = originalManager.getSession()
    let restarted = try SessionManager(
      configuration: SessionConfig(restorePersistedSession: false, sampler: TestSessionSampler(decisions: [.notSampled, .sampled])),
      persistence: persistence
    )
    let dropped = restarted.getSession()
    let third = restarted.resetSession()
    restarted.endSession()
    let sink = InMemoryLogRecordExporter()
    let processor = SessionSamplingLogRecordProcessor(
      nextProcessor: SimpleLogRecordProcessor(logRecordExporter: sink), sessionManager: restarted
    )
    let logger = LoggerProviderBuilder().with(processors: [processor]).build()
    OpenTelemetry.registerLoggerProvider(loggerProvider: logger)
    SessionEventInstrumentation.install()
    let records = sink.getFinishedLogRecords()
    XCTAssertEqual(records.map(\.eventName), ["session.start", "session.end", "session.start", "session.end"])
    XCTAssertEqual(records.map { $0.attributes[SemanticConventions.Session.id.rawValue] },
                   [.string(first.id), .string(first.id), .string(third.id), .string(third.id)])
    XCTAssertEqual(third.previousId, dropped.id)
    XCTAssertNil(restarted.peekSession())
    _ = processor.shutdown()
  }

  func testMetricsAreFilteredBeforeAggregationAndKeepCapturedIdentityAcrossReset() throws {
    let sessions = try manager([.sampled, .notSampled, .sampled])
    let exporter = SamplingMetricExporter()
    let provider = MeterProviderSdk.builder()
      .registerMetricReader(reader: PeriodicMetricReaderBuilder(exporter: exporter).setInterval(timeInterval: 3600).build())
      .registerView(selector: InstrumentSelector.builder().setInstrument(name: "operations").build(),
                    view: View.builder().withAggregation(aggregation: Aggregations.sum()).build()).build()
    defer { _ = provider.shutdown() }
    let counter = provider.get(name: "test").counterBuilder(name: "operations").build()
    let original = sessions.getSession()
    let dropped = sessions.resetSession()
    XCTAssertTrue(original.recordIfSampled { counter.add(value: 2, attributes: $0) })
    XCTAssertFalse(dropped.recordIfSampled { counter.add(value: 100, attributes: $0) })
    let next = sessions.resetSession()
    XCTAssertTrue(next.recordIfSampled { counter.add(value: 3, attributes: $0) })
    XCTAssertEqual(provider.forceFlush(), .success)

    let points = exporter.captured.flatMap(\.data.points).compactMap { $0 as? LongPointData }
    XCTAssertEqual(points.count, 2)
    XCTAssertEqual(points.first { $0.attributes[SemanticConventions.Session.id.rawValue] == .string(original.id) }?.value, 2)
    XCTAssertEqual(points.first { $0.attributes[SemanticConventions.Session.id.rawValue] == .string(next.id) }?.value, 3)
    XCTAssertFalse(points.contains { $0.attributes[SemanticConventions.Session.id.rawValue] == .string(dropped.id) })
  }

  func testBatchFlushAndShutdownReachWrappedProcessor() throws {
    let sessions = try manager([.sampled])
    let exporter = CountingLogRecordExporter()
    let processor = SessionSamplingLogRecordProcessor(
      nextProcessor: BatchLogRecordProcessor(logRecordExporter: exporter, scheduleDelay: 60), sessionManager: sessions
    )
    processor.onEmit(logRecord: TelemetryFixtures.logRecord())
    XCTAssertEqual(exporter.exportedCount, 0)
    XCTAssertEqual(processor.forceFlush(explicitTimeout: 5), .success)
    XCTAssertEqual(exporter.exportedCount, 1)
    processor.onEmit(logRecord: TelemetryFixtures.logRecord())
    XCTAssertEqual(processor.shutdown(explicitTimeout: 5), .success)
    XCTAssertEqual(exporter.exportedCount, 2)
  }

  func testFlushAndShutdownPreserveFailuresAndTimeouts() throws {
    let sink = MockLogRecordProcessor()
    sink.forceFlushResult = .failure
    sink.shutdownResult = .failure
    let processor = try SessionSamplingLogRecordProcessor(nextProcessor: sink, sessionManager: manager([.sampled]))
    XCTAssertEqual(processor.forceFlush(explicitTimeout: 2), .failure)
    XCTAssertEqual(processor.shutdown(explicitTimeout: 3), .failure)
    XCTAssertEqual(sink.forceFlushCalls, [2])
    XCTAssertEqual(sink.shutdownCalls, [3])
  }

  func testSamplerEmittingTelemetryDoesNotCreateAnotherSession() throws {
    let sampler = EmittingSessionSampler()
    let sessions = try SessionManager(configuration: SessionConfig(sampler: sampler), persistence: TestSessionPersistence())
    let spans = SamplingSpanExporter()
    let traces = TracerProviderBuilder().with(sampler: SessionTraceSampler(sessionManager: sessions))
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: spans)).build()
    defer { traces.shutdown() }
    let sink = MockLogRecordProcessor()
    let logs = SessionSamplingLogRecordProcessor(nextProcessor: sink, sessionManager: sessions)
    sampler.emit = {
      traces.get(instrumentationName: "test").spanBuilder(spanName: "sampler").startSpan().end()
      logs.onEmit(logRecord: TelemetryFixtures.logRecord())
    }
    defer { sampler.emit = nil }
    traces.get(instrumentationName: "test").spanBuilder(spanName: "application").startSpan().end()
    traces.forceFlush()
    XCTAssertEqual(sampler.calls, 1)
    XCTAssertEqual(spans.finished.map(\.name), ["application"])
    XCTAssertTrue(sink.receivedLogRecords.isEmpty)
  }

  func testExistingAttributionProcessorsDoNotOptIntoFiltering() throws {
    let sessions = try manager([.notSampled])
    let spans = SamplingSpanExporter()
    let traces = TracerProviderBuilder().add(spanProcessor: SessionSpanProcessor(sessionManager: sessions))
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: spans)).build()
    defer { traces.shutdown() }
    traces.get(instrumentationName: "test").spanBuilder(spanName: "unfiltered").startSpan().end()
    traces.forceFlush()
    let sink = MockLogRecordProcessor()
    SessionLogRecordProcessor(nextProcessor: sink, sessionManager: sessions)
      .onEmit(logRecord: TelemetryFixtures.logRecord())
    XCTAssertEqual(spans.finished.count, 1)
    XCTAssertEqual(sink.receivedLogRecords.count, 1)
  }

  func testConcurrentHistoricalLogsKeepTheirCapturedDecisionDuringResets() throws {
    let sessions = try manager([.sampled, .notSampled])
    let sampled = sessions.getSession()
    let dropped = sessions.resetSession()
    let sink = MockLogRecordProcessor()
    let notificationLock = NSLock()
    nonisolated(unsafe) var expectedIds = Set<String>()
    nonisolated(unsafe) var deliveredIds = Set<String>()
    let observer = NotificationCenter.default.addObserver(forName: SessionEventNotification, object: nil, queue: nil) { notification in
      if let session = notification.object as? Session {
        _ = notificationLock.withLock { deliveredIds.insert(session.id) }
      }
    }
    defer { NotificationCenter.default.removeObserver(observer) }
    // This test shares a stateless wrapper and a synchronized sink across workers.
    nonisolated(unsafe) let processor = SessionSamplingLogRecordProcessor(nextProcessor: sink, sessionManager: sessions)
    DispatchQueue.concurrentPerform(iterations: 30) { index in
      if index.isMultiple(of: 3) {
        let replacement = sessions.resetSession()
        _ = notificationLock.withLock { expectedIds.insert(replacement.id) }
      } else {
        let session = index.isMultiple(of: 2) ? sampled : dropped
        processor.onEmit(logRecord: TelemetryFixtures.logRecord(attributes: session.samplingAttributes))
      }
    }
    let delivered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      notificationLock.withLock { expectedIds.count == 10 && expectedIds.isSubset(of: deliveredIds) }
    }, object: nil)
    wait(for: [delivered], timeout: 5)
    XCTAssertEqual(sink.receivedLogRecords.count, 10)
    XCTAssertTrue(sink.receivedLogRecords.allSatisfy { $0.attributes == sampled.samplingAttributes })
  }

  private func manager(_ decisions: [SessionSamplingDecision],
                       persistence: TestSessionPersistence = TestSessionPersistence()) throws -> SessionManager {
    return try SessionManager(configuration: SessionConfig(sampler: TestSessionSampler(decisions: decisions)), persistence: persistence)
  }
}

private final class EmittingSessionSampler: SessionSampler, @unchecked Sendable {
  var emit: (() -> Void)?
  private(set) var calls = 0
  func samplingDecision(for sessionId: String) -> SessionSamplingDecision {
    calls += 1
    emit?()
    return .sampled
  }
}

private final class ResettingTraceSampler: Sampler {
  let reset: () -> Void
  init(_ reset: @escaping () -> Void) {
    self.reset = reset
  }

  var description: String {
    "ResettingTraceSampler"
  }

  func shouldSample(parentContext: SpanContext?, traceId: TraceId, name: String, kind: SpanKind,
                    attributes: [String: AttributeValue], parentLinks: [SpanData.Link]) -> Decision {
    reset()
    return Samplers.alwaysOn.shouldSample(parentContext: parentContext, traceId: traceId, name: name,
                                          kind: kind, attributes: attributes, parentLinks: parentLinks)
  }
}

private final class SamplingSpanExporter: SpanExporter, @unchecked Sendable {
  private let lock = NSLock()
  private var spans: [SpanData] = []
  var finished: [SpanData] {
    lock.withLock { spans }
  }

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    lock.withLock { self.spans.append(contentsOf: spans) }
    return .success
  }

  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    .success
  }

  func shutdown(explicitTimeout: TimeInterval?) {}
}

private final class SamplingMetricExporter: MetricExporter, @unchecked Sendable {
  private let lock = NSLock()
  private var metrics: [MetricData] = []
  var captured: [MetricData] {
    lock.withLock { metrics }
  }

  func export(metrics: [MetricData]) -> ExportResult {
    lock.withLock { self.metrics.append(contentsOf: metrics) }
    return .success
  }

  func flush() -> ExportResult {
    .success
  }

  func shutdown() -> ExportResult {
    .success
  }

  func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    .cumulative
  }
}

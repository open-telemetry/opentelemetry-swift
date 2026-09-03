/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

// LoggerProviderSdk's witness tables are not linked into OTelSwiftLogTests on
// watchOS (see LogHandlerCoverageTests), so keep these off watchOS too.
#if !os(watchOS)

  import Logging
  @testable import OpenTelemetryApi
  import OpenTelemetrySdk
  @testable import OTelSwiftLog
  import SharedTestUtils
  import XCTest

  /// Stress tests for the swift-log bridge. They only run under Thread
  /// Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
  final class OTelSwiftLogConcurrencyTests: XCTestCase {
    private final class CountingLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
      private let lock = NSLock()
      private var _records: [ReadableLogRecord] = []

      var records: [ReadableLogRecord] {
        lock.lock()
        defer { lock.unlock() }
        return _records
      }

      func onEmit(logRecord: ReadableLogRecord) {
        lock.lock()
        _records.append(logRecord)
        lock.unlock()
      }

      func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
      func shutdown(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    }

    private var processor: CountingLogRecordProcessor!
    private var handler: OTelLogHandler!

    override func setUpWithError() throws {
      try ConcurrencyTesting.skipUnlessEnabled()
      processor = CountingLogRecordProcessor()
      let provider = LoggerProviderBuilder()
        .with(processors: [processor])
        .build()
      handler = OTelLogHandler(loggerProvider: provider, attributes: ["fixture": .string("stress")])
    }

    override func tearDown() {
      processor = nil
      handler = nil
    }

    func testLogThroughSharedLoggerFromManyThreads() {
      let handler = self.handler!
      let logger = Logger(label: "stress") { _ in handler }
      let threads = ConcurrencyTesting.defaultThreads
      let iterations = ConcurrencyTesting.defaultIterations

      ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
        logger.info("message \(iteration)", metadata: ["thread": "\(thread)", "iteration": .stringConvertible(iteration)])
      }

      let records = processor.records
      XCTAssertEqual(records.count, threads * iterations)
      XCTAssertTrue(records.allSatisfy { $0.attributes["thread"] != nil && $0.attributes["iteration"] != nil })
    }

    func testPerThreadLoggerCopiesWithOwnMetadata() {
      let handler = self.handler!
      let base = Logger(label: "stress-copies") { _ in handler }
      let threads = ConcurrencyTesting.defaultThreads
      let iterations = ConcurrencyTesting.defaultIterations

      ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
        var logger = base
        logger[metadataKey: "thread"] = "\(thread)"
        logger.logLevel = .debug
        logger.debug("copy \(iteration)")
        logger.error("copy error \(iteration)", metadata: ["iteration": "\(iteration)"])
      }

      let records = processor.records
      XCTAssertEqual(records.count, 2 * threads * iterations)
      let threadsSeen = Set(records.compactMap { record -> String? in
        if case let .string(value)? = record.attributes["thread"] { return value }
        return nil
      })
      XCTAssertEqual(threadsSeen.count, threads)
    }

    func testLoggingWhileActiveSpanChangesOnEachThread() {
      let handler = self.handler!
      let logger = Logger(label: "stress-spans") { _ in handler }
      let tracer = UncheckedSendable(TracerProviderSdk().get(instrumentationName: "stress"))
      let threads = ConcurrencyTesting.defaultThreads
      let iterations = 50

      OpenTelemetry.withContextManager(ThreadLocalContextManager()) {
        ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
          let span = tracer.value.spanBuilder(spanName: "thread-\(thread)").startSpan()
          OpenTelemetry.instance.contextProvider.setActiveSpan(span)
          logger.info("inside span")
          OpenTelemetry.instance.contextProvider.removeContextForSpan(span)
          span.end()
        }
      }

      let records = processor.records
      XCTAssertEqual(records.count, threads * iterations)
    }
  }

#endif

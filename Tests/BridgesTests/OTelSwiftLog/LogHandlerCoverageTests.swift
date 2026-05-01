/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

// LoggerProviderSdk's witness tables are not linked into OTelSwiftLogTests on
// watchOS, so keep these tests off watchOS. They still exercise the handler on
// every other platform where `swift test` runs.
#if !os(watchOS)

import Logging
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import OTelSwiftLog
import XCTest

final class OTelLogHandlerCoverageTests: XCTestCase {
  private final class RecordingLogRecordProcessor: LogRecordProcessor {
    private let lock = NSLock()
    private var _records: [ReadableLogRecord] = []
    var records: [ReadableLogRecord] {
      lock.lock(); defer { lock.unlock() }
      return _records
    }
    func onEmit(logRecord: ReadableLogRecord) {
      lock.lock(); defer { lock.unlock() }
      _records.append(logRecord)
    }
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult { .success }
  }

  private func makeProvider() -> (LoggerProviderSdk, RecordingLogRecordProcessor) {
    let processor = RecordingLogRecordProcessor()
    let provider = LoggerProviderBuilder()
      .with(processors: [processor])
      .build()
    return (provider, processor)
  }

  func testLogHandlerDefaultLogLevelIsInfo() {
    let handler = OTelLogHandler()
    XCTAssertEqual(handler.logLevel, .info)
  }

  func testLogHandlerLogEmitsRecordWithBody() {
    let (provider, processor) = makeProvider()
    let handler = OTelLogHandler(loggerProvider: provider)

    let logger = Logger(label: "OTelSwiftLogTests-body") { _ in handler }
    logger.info("hello from otelswiftlog")

    XCTAssertEqual(processor.records.count, 1)
    XCTAssertEqual(processor.records.first?.body, .string("hello from otelswiftlog"))
  }

  func testLogHandlerIncludesSourceFileFunctionLineAttributes() {
    let (provider, processor) = makeProvider()
    let handler = OTelLogHandler(loggerProvider: provider)

    let logger = Logger(label: "OTelSwiftLogTests-src") { _ in handler }
    logger.warning("warn-msg")

    let attrs = processor.records.first?.attributes ?? [:]
    XCTAssertNotNil(attrs["source"])
    XCTAssertNotNil(attrs["file"])
    XCTAssertNotNil(attrs["function"])
    XCTAssertNotNil(attrs["line"])
  }

  func testLogHandlerAppliesMethodMetadataAsAttributes() {
    let (provider, processor) = makeProvider()
    let handler = OTelLogHandler(loggerProvider: provider)

    let logger = Logger(label: "OTelSwiftLogTests-md") { _ in handler }
    logger.info("msg", metadata: ["request-id": .string("abc")])

    XCTAssertEqual(processor.records.first?.attributes["request-id"], .string("abc"))
  }

  func testLogHandlerAppliesHandlerStructMetadataAsAttributes() {
    let (provider, processor) = makeProvider()
    var handler = OTelLogHandler(loggerProvider: provider)
    handler.metadata = ["env": "test"]

    let logger = Logger(label: "OTelSwiftLogTests-sm") { _ in handler }
    logger.info("msg")

    XCTAssertEqual(processor.records.first?.attributes["env"], .string("test"))
  }

  func testLogHandlerMapsAllSeverityLevels() {
    let (provider, processor) = makeProvider()
    var handler = OTelLogHandler(loggerProvider: provider)
    handler.logLevel = .trace
    let logger = Logger(label: "OTelSwiftLogTests-sev") { _ in handler }

    logger.trace("t")
    logger.debug("d")
    logger.info("i")
    logger.notice("n")
    logger.warning("w")
    logger.error("e")
    logger.critical("c")

    let severities = processor.records.map { $0.severity }
    XCTAssertEqual(severities, [
      .trace, .debug, .info, .info2, .warn, .error, .error2
    ])
  }

  func testLogHandlerSubscriptAndMetadataAssign() {
    var handler = OTelLogHandler()
    handler[metadataKey: "x"] = "y"
    XCTAssertEqual(handler[metadataKey: "x"], "y")
    handler.metadata["another"] = .string("value")
    XCTAssertEqual(handler.metadata["another"], .string("value"))
  }

  func testLogHandlerAttachesSpanContextWhenActiveSpanSet() {
    // Snapshot + restore the process-global tracer provider so this test
    // doesn't affect any test class that runs after it in the same bundle.
    let savedTracerProvider = OpenTelemetry.instance.tracerProvider
    defer { OpenTelemetry.registerTracerProvider(tracerProvider: savedTracerProvider) }

    OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderSdk())
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "t")
    let span = tracer.spanBuilder(spanName: "parent").startSpan()
    defer { span.end() }

    let (provider, processor) = makeProvider()
    let handler = OTelLogHandler(loggerProvider: provider)
    let logger = Logger(label: "OTelSwiftLogTests-ctx") { _ in handler }

    // `withActiveSpan(_:_:)` sets span as active only for the duration of the
    // closure; unlike `setActiveSpan`, it works on every platform (the macOS
    // `ActivityContextManager` and the Linux default both honor it).
    OpenTelemetry.instance.contextProvider.withActiveSpan(span) {
      logger.info("with-span-context")
    }

    XCTAssertEqual(processor.records.first?.spanContext, span.context)
  }
}

#endif

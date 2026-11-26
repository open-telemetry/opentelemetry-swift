/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import ScreenInstrumentation

/// Collects the log records a processor is handed.
final class RecordingLogRecordProcessor: LogRecordProcessor, @unchecked Sendable {
  private let lock = NSLock()
  private var _records: [ReadableLogRecord] = []
  private var _shutdownCount = 0
  private var _forceFlushCount = 0

  var records: [ReadableLogRecord] { lock.withLock { _records } }
  var shutdownCount: Int { lock.withLock { _shutdownCount } }
  var forceFlushCount: Int { lock.withLock { _forceFlushCount } }

  func onEmit(logRecord: ReadableLogRecord) {
    lock.withLock { _records.append(logRecord) }
  }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
    lock.withLock { _shutdownCount += 1 }
    return .success
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
    lock.withLock { _forceFlushCount += 1 }
    return .success
  }
}

/// Collects the spans a processor sees end.
final class RecordingSpanProcessor: SpanProcessor, @unchecked Sendable {
  var isStartRequired = false
  var isEndRequired = true

  private let lock = NSLock()
  private var _spans: [SpanData] = []

  var spans: [SpanData] { lock.withLock { _spans } }

  func onStart(parentContext: SpanContext?, span: ReadableSpan) {}

  func onEnd(span: ReadableSpan) {
    let data = span.toSpanData()
    lock.withLock { _spans.append(data) }
  }

  func shutdown(explicitTimeout: TimeInterval?) {}

  func forceFlush(timeout: TimeInterval?) {}
}

/// A span the processors can write attributes to.
final class StubReadableSpan: ReadableSpan, @unchecked Sendable {
  var capturedAttributes: [String: AttributeValue] = [:]

  var hasEnded = false
  var latency: TimeInterval = 0
  var kind: SpanKind = .internal
  var instrumentationScopeInfo = InstrumentationScopeInfo()
  var name = "StubSpan"
  var context: SpanContext = .create(traceId: TraceId.random(),
                                     spanId: SpanId.random(),
                                     traceFlags: TraceFlags(),
                                     traceState: TraceState())
  var isRecording = true
  var status: Status = .unset
  var description = "StubReadableSpan"

  func getAttributes() -> [String: AttributeValue] { capturedAttributes }

  func setAttributes(_ attributes: [String: AttributeValue]) {
    capturedAttributes.merge(attributes) { _, new in new }
  }

  func setAttribute(key: String, value: AttributeValue?) {
    guard let value else { return }
    capturedAttributes[key] = value
  }

  func end() {}
  func end(time: Date) {}

  func toSpanData() -> SpanData {
    SpanData(traceId: context.traceId,
             spanId: context.spanId,
             traceFlags: context.traceFlags,
             traceState: TraceState(),
             resource: Resource(attributes: [String: AttributeValue]()),
             instrumentationScope: InstrumentationScopeInfo(),
             name: name,
             kind: kind,
             startTime: Date(),
             endTime: Date(),
             hasRemoteParent: false)
  }

  func updateName(name: String) { self.name = name }

  func addEvent(name: String) {}
  func addEvent(name: String, attributes: [String: AttributeValue]) {}
  func addEvent(name: String, timestamp: Date) {}
  func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}
  func recordException(_ exception: SpanException) {}
  func recordException(_ exception: any SpanException, timestamp: Date) {}
  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue]) {}
  func recordException(_ exception: any SpanException,
                       attributes: [String: AttributeValue],
                       timestamp: Date) {}
  func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) {}
}

enum ScreenTestFixtures {
  /// Registers providers that record everything, and returns what they recorded.
  @discardableResult
  static func registerRecordingProviders() -> (spans: RecordingSpanProcessor, logs: RecordingLogRecordProcessor) {
    let spanProcessor = RecordingSpanProcessor()
    let logProcessor = RecordingLogRecordProcessor()

    OpenTelemetry.registerTracerProvider(tracerProvider:
      TracerProviderBuilder().add(spanProcessor: spanProcessor).build())
    OpenTelemetry.registerLoggerProvider(loggerProvider:
      LoggerProviderBuilder().with(processors: [logProcessor]).build())

    return (spanProcessor, logProcessor)
  }

  static func logRecord(attributes: [String: AttributeValue] = [:]) -> ReadableLogRecord {
    ReadableLogRecord(resource: Resource(attributes: [:]),
                      instrumentationScopeInfo: InstrumentationScopeInfo(),
                      timestamp: Date(),
                      observedTimestamp: Date(),
                      spanContext: nil,
                      severity: .info,
                      body: .string("test"),
                      attributes: attributes)
  }

  static func string(_ value: AttributeValue?) -> String? {
    guard case let .string(string)? = value else { return nil }
    return string
  }
}

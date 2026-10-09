/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class SpanSdkConcurrencyTests: XCTestCase {
  private let idGenerator: IdGenerator = RandomIdGenerator()
  private let resource = Resource()
  private let instrumentationScopeInfo = InstrumentationScopeInfo(name: "ConcurrencyTest")

  private func createSpan(spanProcessor: SpanProcessor = NoopSpanProcessor(),
                           spanLimits: SpanLimits = SpanLimits()) -> SpanSdk {
    let traceId = idGenerator.generateTraceId()
    let spanId = idGenerator.generateSpanId()
    let context = SpanContext.create(traceId: traceId, spanId: spanId,
                                     traceFlags: TraceFlags().settingIsSampled(true),
                                     traceState: TraceState())
    var attributes = AttributesDictionary(capacity: spanLimits.attributeCountLimit)
    return SpanSdk.startSpan(context: context,
                             name: "test-span",
                             instrumentationScopeInfo: instrumentationScopeInfo,
                             kind: .internal,
                             parentContext: nil,
                             hasRemoteParent: false,
                             spanLimits: spanLimits,
                             spanProcessor: spanProcessor,
                             clock: MillisClock(),
                             resource: resource,
                             attributes: attributes,
                             links: [],
                             totalRecordedLinks: 0,
                             startTime: nil)
  }

  // MARK: - Concurrent setAttribute

  func testConcurrentSetAttribute() {
    let span = createSpan()
    let writers = 8
    let attrsPerWriter = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.span.setAttribute", attributes: .concurrent)

    for w in 0..<writers {
      for a in 0..<attrsPerWriter {
        group.enter()
        queue.async {
          span.setAttribute(key: "writer-\(w)-attr-\(a)", value: .int(w * 1000 + a))
          group.leave()
        }
      }
    }

    waitForConcurrentWork(group, "Concurrent setAttribute should complete without deadlock")

    let spanData = span.toSpanData()
    XCTAssertLessThanOrEqual(spanData.attributes.count, SpanLimits().attributeCountLimit)
    for (_, value) in spanData.attributes {
      if case .int(let v) = value {
        XCTAssertGreaterThanOrEqual(v, 0)
      } else {
        XCTFail("Unexpected attribute type — possible torn read")
      }
    }
    span.end()
  }

  // MARK: - Concurrent addEvent

  func testConcurrentAddEvent() {
    let span = createSpan()
    let totalEvents = 500
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.span.addEvent", attributes: .concurrent)

    for i in 0..<totalEvents {
      group.enter()
      queue.async {
        span.addEvent(name: "event-\(i)")
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent addEvent should complete without deadlock")

    let spanData = span.toSpanData()
    XCTAssertEqual(spanData.totalRecordedEvents, totalEvents)
    XCTAssertLessThanOrEqual(spanData.events.count, SpanLimits().eventCountLimit)
    span.end()
  }

  // MARK: - Concurrent reads while writing

  func testConcurrentReadWhileWriting() {
    let span = createSpan()
    let iterations = 500
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.span.readWrite", attributes: .concurrent)

    for i in 0..<iterations {
      group.enter()
      queue.async {
        span.setAttribute(key: "key-\(i)", value: .string("value-\(i)"))
        group.leave()
      }

      group.enter()
      queue.async {
        span.addEvent(name: "event-\(i)")
        group.leave()
      }

      group.enter()
      queue.async {
        let data = span.toSpanData()
        XCTAssertFalse(data.name.isEmpty, "Name should never be empty (torn read)")
        group.leave()
      }

      group.enter()
      queue.async {
        _ = span.name
        _ = span.status
        _ = span.isRecording
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent read/write should complete without deadlock")
    span.end()
  }

  // MARK: - Concurrent end (idempotency)

  func testConcurrentEnd() {
    let processor = AtomicCountingSpanProcessor()
    let span = createSpan(spanProcessor: processor)
    let threads = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.span.end", attributes: .concurrent)

    for _ in 0..<threads {
      group.enter()
      queue.async {
        span.end()
        group.leave()
      }
    }

    waitForConcurrentWork(group, "concurrent work should complete")
    XCTAssertEqual(processor.onEndCount, 1, "onEnd must be called exactly once regardless of concurrent end() calls")
    XCTAssertTrue(span.hasEnded)
  }

  // MARK: - setAttribute after end is no-op

  func testSetAttributeAfterEnd() {
    let span = createSpan()
    span.setAttribute(key: "before-end", value: .string("exists"))
    span.end()

    let countAfterEnd = span.toSpanData().attributes.count
    let threads = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.span.afterEnd", attributes: .concurrent)

    for i in 0..<threads {
      group.enter()
      queue.async {
        span.setAttribute(key: "after-end-\(i)", value: .int(i))
        group.leave()
      }
    }

    waitForConcurrentWork(group, "concurrent work should complete")
    XCTAssertEqual(span.toSpanData().attributes.count, countAfterEnd,
                   "No attributes should be added after end()")
  }

  // MARK: - Concurrent setName

  func testConcurrentSetName() {
    let span = createSpan()
    let names = (0..<50).map { "name-\($0)" }
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.span.setName", attributes: .concurrent)

    for name in names {
      group.enter()
      queue.async {
        span.name = name
        group.leave()
      }
    }

    waitForConcurrentWork(group, "concurrent work should complete")
    XCTAssertTrue(names.contains(span.name), "Final name must be one of the set values, got: \(span.name)")
    span.end()
  }
}

// MARK: - Thread-safe span processor for testing

private final class AtomicCountingSpanProcessor: SpanProcessor, @unchecked Sendable {
  private let lock = NSLock()
  private var _onEndCount = 0

  var onEndCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _onEndCount
  }

  let isStartRequired = false
  let isEndRequired = true

  func onStart(parentContext: SpanContext?, span: ReadableSpan) {}

  func onEnd(span: ReadableSpan) {
    lock.lock()
    _onEndCount += 1
    lock.unlock()
  }

  func shutdown(explicitTimeout: TimeInterval?) {}
  func forceFlush(timeout: TimeInterval?) {}
}

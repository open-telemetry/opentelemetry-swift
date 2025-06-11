//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk

final class RecordEventsReadableSpanPerformanceTests: XCTestCase {
  var tracerSdkFactory = TracerProviderSdk()
  var tracerSdk: Tracer!

  override func setUp() {
    super.setUp()
    tracerSdk = tracerSdkFactory.get(instrumentationName: "SpanBuilderSdkTest")
  }

  private func createTestSpan() -> RecordEventsReadableSpan {
    tracerSdk.spanBuilder(spanName: name).startSpan() as! RecordEventsReadableSpan
  }

  func testAddEventPerformance() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      for _ in 0 ..< 100_000 {
        span.addEvent(name: UUID().uuidString)
      }
    }
  }

  func testSetAttributePerformance() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      for i in 0 ..< 100_000 {
        span.setAttribute(key: "key\(i)", value: .string("value"))
      }
    }
  }

  func testSetStatusPerformance() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      for _ in 0 ..< 100_000 {
        span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
      }
    }
  }

  func testAllOperationsTogetherPerformance() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      for i in 0 ..< 100_000 {
        span.setAttribute(key: "key\(i)", value: .string("value"))
        span.addEvent(name: UUID().uuidString)
        span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
        _ = span.toSpanData()
      }
    }
  }

  func testAddEventPerformance_concurrent() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      DispatchQueue.concurrentPerform(iterations: 100_000) { _ in
        span.addEvent(name: UUID().uuidString)
      }
    }
  }

  func testSetAttributePerformance_concurrent() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      DispatchQueue.concurrentPerform(iterations: 100_000) { i in
        span.setAttribute(key: "key\(i)", value: .string("value"))
      }
    }
  }

  func testSetStatusPerformance_concurrent() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      DispatchQueue.concurrentPerform(iterations: 100_000) { _ in
        span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
      }
    }
  }

  func testAllOperationsTogetherPerformance_concurrent() {
    let span = createTestSpan()

    measure(metrics: [XCTClockMetric()]) {
      DispatchQueue.concurrentPerform(iterations: 100_000) { i in
        span.setAttribute(key: "key\(i)", value: .string("value"))
        span.addEvent(name: UUID().uuidString)
        span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
        _ = span.toSpanData()
      }
    }
  }
}

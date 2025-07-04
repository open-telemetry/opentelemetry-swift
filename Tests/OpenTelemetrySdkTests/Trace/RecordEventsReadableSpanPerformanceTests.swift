//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

  import XCTest
  @testable import OpenTelemetryApi
  @testable import OpenTelemetrySdk

  final class SpanSdkPerformanceTests: XCTestCase {
    var tracerSdkFactory = TracerProviderSdk()
    var tracerSdk: Tracer!

    let iterations = 10_000

    override func setUp() {
      super.setUp()
      tracerSdk = tracerSdkFactory.get(instrumentationName: "SpanBuilderSdkTest")
    }

    private func createTestSpan() -> SpanSdk {
      tracerSdk.spanBuilder(spanName: name).startSpan() as! SpanSdk
    }

    func testAddEventPerformance() {
      let span = createTestSpan()

      measure(metrics: [XCTClockMetric()]) {
        for _ in 0 ..< iterations {
          span.addEvent(name: UUID().uuidString)
        }
      }
    }

    func testSetAttributePerformance() {
      let span = createTestSpan()

      measure(metrics: [XCTClockMetric()]) {
        for i in 0 ..< iterations {
          span.setAttribute(key: "key\(i)", value: .string("value"))
        }
      }
    }

    func testSetStatusPerformance() {
      let span = createTestSpan()

      measure(metrics: [XCTClockMetric()]) {
        for _ in 0 ..< iterations {
          span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
        }
      }
    }

    func testAllOperationsTogetherPerformance() {
      let span = createTestSpan()

      measure(metrics: [XCTClockMetric()]) {
        for i in 0 ..< iterations {
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
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
          span.addEvent(name: UUID().uuidString)
        }
      }
    }

    func testSetAttributePerformance_concurrent() {
      let span = createTestSpan()

      measure(metrics: [XCTClockMetric()]) {
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
          span.setAttribute(key: "key\(i)", value: .string("value"))
        }
      }
    }

    func testSetStatusPerformance_concurrent() {
      let span = createTestSpan()

      measure(metrics: [XCTClockMetric()]) {
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
          span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
        }
      }
    }

    func testAllOperationsTogetherPerformance_concurrent() {
      let span = createTestSpan()

      measure(metrics: [XCTClockMetric()]) {
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
          span.setAttribute(key: "key\(i)", value: .string("value"))
          span.addEvent(name: UUID().uuidString)
          span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
          _ = span.toSpanData()
        }
      }
    }
  }

#endif

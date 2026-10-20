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

    /// True when the ThreadSanitizer runtime is loaded into the process.
    private static let isThreadSanitizerLoaded =
      dlsym(UnsafeMutableRawPointer(bitPattern: -2) /* RTLD_DEFAULT */, "__tsan_init") != nil

    /// Measures `body` with XCTest's `measure` API. Under ThreadSanitizer the
    /// measurement instruments (MXMInstrument) crash intermittently and timings
    /// are skewed 2-20x anyway, so the body runs un-measured instead -- keeping
    /// the workload visible to TSan's race detection. It still runs 5 times to
    /// match `measure`'s default iteration count: same accumulated span state,
    /// and each repeat gives TSan a fresh set of interleavings to observe.
    private func measureOrRunUnmeasured(_ body: () -> Void) {
      if Self.isThreadSanitizerLoaded {
        for _ in 0 ..< 5 {
          body()
        }
      } else {
        measure(metrics: [XCTClockMetric()], block: body)
      }
    }

    override func setUp() {
      super.setUp()
      tracerSdk = tracerSdkFactory.get(instrumentationName: "SpanBuilderSdkTest")
    }

    private func createTestSpan() -> SpanSdk {
      tracerSdk.spanBuilder(spanName: name).startSpan() as! SpanSdk
    }

    func testAddEventPerformance() {
      let span = createTestSpan()

      measureOrRunUnmeasured {
        for _ in 0 ..< iterations {
          span.addEvent(name: UUID().uuidString)
        }
      }
    }

    func testSetAttributePerformance() {
      let span = createTestSpan()

      measureOrRunUnmeasured {
        for i in 0 ..< iterations {
          span.setAttribute(key: "key\(i)", value: .string("value"))
        }
      }
    }

    func testSetStatusPerformance() {
      let span = createTestSpan()

      measureOrRunUnmeasured {
        for _ in 0 ..< iterations {
          span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
        }
      }
    }

    func testAllOperationsTogetherPerformance() {
      let span = createTestSpan()

      measureOrRunUnmeasured {
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

      measureOrRunUnmeasured {
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
          span.addEvent(name: UUID().uuidString)
        }
      }
    }

    func testSetAttributePerformance_concurrent() {
      let span = createTestSpan()

      measureOrRunUnmeasured {
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
          span.setAttribute(key: "key\(i)", value: .string("value"))
        }
      }
    }

    func testSetStatusPerformance_concurrent() {
      let span = createTestSpan()

      measureOrRunUnmeasured {
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
          span.status = Int.random(in: 0 ... 10) % 2 == 0 ? .ok : .unset
        }
      }
    }

    func testAllOperationsTogetherPerformance_concurrent() {
      let span = createTestSpan()

      measureOrRunUnmeasured {
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

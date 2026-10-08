/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import CoreMetrics
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import SharedTestUtils
@testable import SwiftMetricsShim
import XCTest

/// Stress tests for the swift-metrics shim. They only run under Thread
/// Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`); see `ConcurrencyTesting`.
final class SwiftMetricsShimConcurrencyTests: XCTestCase {
  private final class CollectingExporter: MetricExporter, @unchecked Sendable {
    private let lock = NSLock()
    private var latest: [MetricData] = []

    var exported: [MetricData] {
      lock.lock()
      defer { lock.unlock() }
      return latest
    }

    func export(metrics: [MetricData]) -> ExportResult {
      lock.lock()
      latest = metrics
      lock.unlock()
      return .success
    }

    func flush() -> ExportResult { .success }
    func shutdown() -> ExportResult { .success }
    func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality { .cumulative }
  }

  private var exporter: CollectingExporter!
  private var reader: PeriodicMetricReaderSdk!
  private var provider: MeterProviderSdk!
  private var metrics: OpenTelemetrySwiftMetrics!

  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    exporter = CollectingExporter()
    // A very long interval so only `forceFlush` drives collection.
    reader = PeriodicMetricReaderSdk(exporter: exporter, exportInterval: 3600)
    // Without a matching view the SDK allocates no storage for an
    // instrument, so register a catch-all view like the existing tests do.
    provider = MeterProviderSdk.builder()
      .registerView(selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
                    view: View.builder().build())
      .registerMetricReader(reader: reader)
      .build()
    metrics = OpenTelemetrySwiftMetrics(meter: provider.meterBuilder(name: "concurrency").build())
  }

  override func tearDown() {
    _ = reader?.shutdown()
    reader = nil
    provider = nil
    metrics = nil
    exporter = nil
  }

  private var registeredMetricCount: Int {
    metrics.lock.withLock { metrics.metrics.count }
  }

  private func exportedMetric(named name: String) -> MetricData? {
    _ = reader.forceFlush()
    return exporter.exported.first { $0.name == name }
  }

  // MARK: - Factory

  func testMakeCounterWithSameLabelFromManyThreadsReturnsOneInstance() {
    let metrics = self.metrics!
    let handlers = ConcurrentCollector<ObjectIdentifier>()

    ConcurrencyTesting.stress { _, _ in
      let handler = metrics.makeCounter(label: "shared_counter", dimensions: [("dim", "value")])
      handlers.append(ObjectIdentifier(handler))
    }

    XCTAssertEqual(Set(handlers.values).count, 1)
    XCTAssertEqual(registeredMetricCount, 1)
  }

  func testMakeEveryInstrumentTypeFromManyThreads() {
    let metrics = self.metrics!
    let threads = ConcurrencyTesting.defaultThreads

    ConcurrencyTesting.stress(threads: threads) { thread, _ in
      for label in ["shared", "thread_\(thread)"] {
        _ = metrics.makeCounter(label: label, dimensions: [])
        _ = metrics.makeRecorder(label: label, dimensions: [], aggregate: true)
        _ = metrics.makeRecorder(label: label, dimensions: [], aggregate: false)
        _ = metrics.makeTimer(label: label, dimensions: [])
      }
    }

    // Per label: one counter, one histogram (the non-aggregating recorder
    // resolves to the existing histogram), one timer.
    XCTAssertEqual(registeredMetricCount, 3 * (threads + 1))
  }

  func testMakeRacingDestroyOnSameLabel() {
    let metrics = self.metrics!

    // Only the factory is exercised here. Recording through two handlers of
    // the same instrument reaches shared storage in the core SDK whose
    // exemplar reservoir is not synchronized; that belongs upstream.
    ConcurrencyTesting.stress { thread, _ in
      if thread.isMultiple(of: 2) {
        _ = metrics.makeCounter(label: "churn", dimensions: [])
        _ = metrics.makeTimer(label: "churn", dimensions: [])
      } else {
        metrics.destroyCounter(metrics.makeCounter(label: "churn", dimensions: []))
        metrics.destroyTimer(metrics.makeTimer(label: "churn", dimensions: []))
      }
    }

    XCTAssertLessThanOrEqual(registeredMetricCount, 2)
  }

  // MARK: - Recording

  func testIncrementSharedCounterFromManyThreads() throws {
    let counter = metrics.makeCounter(label: "hits", dimensions: [("dim", "value")])
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { _, _ in
      counter.increment(by: 1)
    }

    let metric = try XCTUnwrap(exportedMetric(named: "hits"))
    let point = try XCTUnwrap(metric.data.points.last as? LongPointData)
    XCTAssertEqual(metric.type, .LongSum)
    XCTAssertEqual(point.value, threads * iterations)
  }

  func testRecordOnSharedRecordersFromManyThreads() throws {
    let gauge = metrics.makeRecorder(label: "gauge", dimensions: [], aggregate: false)
    let histogram = metrics.makeRecorder(label: "histogram", dimensions: [], aggregate: true)
    let timer = metrics.makeTimer(label: "timer", dimensions: [])
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      gauge.record(Double(thread))
      histogram.record(Int64(iteration))
      timer.recordNanoseconds(1)
    }

    XCTAssertNotNil(exportedMetric(named: "gauge"))
    let histogramData = try XCTUnwrap(exportedMetric(named: "histogram"))
    let histogramPoint = try XCTUnwrap(histogramData.data.points.last as? HistogramPointData)
    XCTAssertEqual(histogramPoint.count, UInt64(threads * iterations))
    let timerData = try XCTUnwrap(exportedMetric(named: "timer"))
    let timerPoint = try XCTUnwrap(timerData.data.points.last as? DoublePointData)
    XCTAssertEqual(timerPoint.value, Double(threads * iterations))
  }

  // MARK: - swift-metrics front door

  func testMetricsSystemInstrumentsFromManyThreads() throws {
    // `MetricsSystem` is process-global; the existing tests bootstrap it the
    // same way, and re-bootstrapping replaces the factory for this test.
    MetricsSystem.bootstrapInternal(metrics)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
      Counter(label: "system_counter").increment()
      Recorder(label: "system_recorder").record(Double(thread))
      Gauge(label: "system_gauge").record(thread)
      Timer(label: "system_timer").recordNanoseconds(1)
    }

    let counter = try XCTUnwrap(exportedMetric(named: "system_counter"))
    let point = try XCTUnwrap(counter.data.points.last as? LongPointData)
    XCTAssertEqual(point.value, threads * iterations)
    XCTAssertNotNil(exportedMetric(named: "system_recorder"))
    XCTAssertNotNil(exportedMetric(named: "system_gauge"))
    XCTAssertNotNil(exportedMetric(named: "system_timer"))
  }

  // MARK: - Locks

  func testLockedValueUnderContention() {
    let value = SwiftMetricsShim.Locked(initialValue: 0)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
      if thread.isMultiple(of: 2) {
        value.protectedValue += 1
      } else {
        value.locking { $0 += 1 }
      }
      _ = value.protectedValue
    }

    XCTAssertEqual(value.protectedValue, threads * iterations)
  }

  func testReadWriteLockUnderContention() {
    let lock = UncheckedSendable(SwiftMetricsShim.ReadWriteLock())
    let counter = ConcurrentCounter()
    nonisolated(unsafe) var guarded = 0
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = ConcurrencyTesting.defaultIterations

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, _ in
      if thread.isMultiple(of: 4) {
        lock.value.withWriterLockVoid { guarded += 1 }
        counter.increment()
      } else {
        _ = lock.value.withReaderLock { guarded }
      }
    }

    XCTAssertEqual(guarded, counter.value)
  }
}

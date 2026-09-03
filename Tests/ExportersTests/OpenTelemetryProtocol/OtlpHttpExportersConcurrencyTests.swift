/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import SharedTestUtils
import XCTest

/// Stress tests for the OTLP/HTTP exporters. The HTTP client is a stub that
/// completes on a background queue, like `URLSession` does, so the exporters'
/// completion handlers run on a different thread than the caller. They only
/// run under Thread Sanitizer (or with `OTEL_CONCURRENCY_TESTS=1`).
final class OtlpHttpExportersConcurrencyTests: XCTestCase {
  /// Completes every request asynchronously on a concurrent queue.
  private final class BackgroundStubHTTPClient: HTTPClient, @unchecked Sendable {
    enum Mode {
      case succeed
      case fail
      /// Fails every other request so the exporters exercise their requeue paths.
      case alternate
    }

    private let mode: Mode
    private let lock = NSLock()
    private var sent = 0
    private var completed = 0
    private let queue = DispatchQueue(label: "BackgroundStubHTTPClient", attributes: .concurrent)

    init(mode: Mode) {
      self.mode = mode
    }

    var sentCount: Int {
      lock.lock()
      defer { lock.unlock() }
      return sent
    }

    private func nextOutcome(for request: URLRequest) -> Result<HTTPURLResponse, Error> {
      lock.lock()
      sent += 1
      let sequence = sent
      lock.unlock()

      let shouldFail: Bool
      switch mode {
      case .succeed: shouldFail = false
      case .fail: shouldFail = true
      case .alternate: shouldFail = sequence.isMultiple(of: 2)
      }
      if shouldFail {
        return .failure(StubError.transient)
      }
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
      return .success(response)
    }

    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
      let outcome = nextOutcome(for: request)
      nonisolated(unsafe) let completion = completion
      queue.async {
        completion(outcome)
        self.markCompleted()
      }
    }

    private func markCompleted() {
      lock.lock()
      completed += 1
      lock.unlock()
    }

    func send(request: URLRequest) async throws -> HTTPURLResponse {
      let outcome = nextOutcome(for: request)
      markCompleted()
      return try outcome.get()
    }

    /// Waits until every completion handler has run, so a test can inspect
    /// exporter state without racing a late callback.
    func waitForAllCompletions(timeout: TimeInterval = 10) -> Bool {
      let deadline = Date(timeIntervalSinceNow: timeout)
      while Date() < deadline {
        lock.lock()
        let done = completed == sent
        lock.unlock()
        if done { return true }
        Thread.sleep(forTimeInterval: 0.01)
      }
      return false
    }
  }

  private enum StubError: Error {
    case transient
  }

  private let endpoint = URL(string: "http://localhost:4318/v1/stress")!

  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
  }

  // MARK: - Traces

  func testSpanExportsFromManyThreads() {
    let client = BackgroundStubHTTPClient(mode: .succeed)
    let exporter = OtlpHttpTraceExporter(endpoint: endpoint, config: OtlpConfiguration(), httpClient: client, envVarHeaders: nil)
    let successes = ConcurrentCounter()
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      let spans = [TelemetryFixtures.spanData(name: "span-\(thread)-\(iteration)")]
      if exporter.export(spans: spans) == .success {
        successes.increment()
      }
    }

    XCTAssertTrue(client.waitForAllCompletions())
    XCTAssertEqual(successes.value, threads * iterations)
    XCTAssertEqual(client.sentCount, threads * iterations)
    XCTAssertTrue(exporter.pendingSpans.isEmpty)
  }

  func testSpanExportRacesFlushWithRequeuedFailures() {
    let client = BackgroundStubHTTPClient(mode: .alternate)
    let exporter = OtlpHttpTraceExporter(endpoint: endpoint, config: OtlpConfiguration(), httpClient: client, envVarHeaders: nil)

    ConcurrencyTesting.stress(threads: ConcurrencyTesting.defaultThreads, iterations: 50) { thread, _ in
      switch thread {
      case 0:
        _ = exporter.flush()
      case 1:
        exporter.shutdown()
      default:
        _ = exporter.export(spans: [TelemetryFixtures.spanData()])
      }
    }

    XCTAssertTrue(client.waitForAllCompletions())
    _ = exporter.flush()
    XCTAssertTrue(client.waitForAllCompletions())
  }

  // MARK: - Logs

  func testLogExportsFromManyThreadsRaceFlush() {
    let client = BackgroundStubHTTPClient(mode: .alternate)
    let exporter = OtlpHttpLogExporter(endpoint: endpoint, config: OtlpConfiguration(), httpClient: client, envVarHeaders: nil)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      if thread == 0 {
        _ = exporter.forceFlush()
      } else {
        _ = exporter.export(logRecords: [TelemetryFixtures.logRecord(body: "log-\(thread)-\(iteration)")])
      }
    }

    XCTAssertTrue(client.waitForAllCompletions())
    XCTAssertGreaterThanOrEqual(client.sentCount, (threads - 1) * iterations)
  }

  // MARK: - Metrics

  func testMetricExportsFromManyThreadsRaceFlush() {
    let client = BackgroundStubHTTPClient(mode: .alternate)
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, config: OtlpConfiguration(), httpClient: client, envVarHeaders: nil)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      switch thread {
      case 0:
        _ = exporter.flush()
      case 1:
        _ = exporter.getAggregationTemporality(for: .counter)
        _ = exporter.getDefaultAggregation(for: .histogram)
      default:
        _ = exporter.export(metrics: [TelemetryFixtures.metricData(name: "metric_\(thread)_\(iteration)")])
      }
    }

    XCTAssertTrue(client.waitForAllCompletions())
    XCTAssertGreaterThanOrEqual(client.sentCount, (threads - 2) * iterations)
  }

  // MARK: - Shared configuration

  func testHeadersProviderIsReadFromManyExportThreadsWhileUpdated() {
    let client = BackgroundStubHTTPClient(mode: .succeed)
    let provider = MutableHeadersProvider([("Authorization", "Bearer initial")])
    let config = OtlpConfiguration(headersProvider: { provider.currentHeaders() })
    let exporter = OtlpHttpTraceExporter(endpoint: endpoint, config: config, httpClient: client, envVarHeaders: nil)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { thread, iteration in
      if thread == 0 {
        provider.update([("Authorization", "Bearer rotated-\(iteration)")])
      } else {
        _ = exporter.export(spans: [TelemetryFixtures.spanData()])
      }
    }

    XCTAssertTrue(client.waitForAllCompletions())
    XCTAssertEqual(provider.callCount, (threads - 1) * iterations)
  }

  func testExporterMetricsAreRecordedFromCallerAndCallbackThreads() throws {
    let client = BackgroundStubHTTPClient(mode: .alternate)
    let collector = CollectingMetricExporter()
    let reader = PeriodicMetricReaderSdk(exporter: collector, exportInterval: 3600)
    let meterProvider = MeterProviderSdk.builder()
      .registerView(selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
                    view: View.builder().build())
      .registerMetricReader(reader: reader)
      .build()
    defer { _ = reader.shutdown() }
    let exporter = OtlpHttpTraceExporter(endpoint: endpoint,
                                         config: OtlpConfiguration(),
                                         meterProvider: meterProvider,
                                         httpClient: client,
                                         envVarHeaders: nil)
    let threads = ConcurrencyTesting.defaultThreads
    let iterations = 50

    ConcurrencyTesting.stress(threads: threads, iterations: iterations) { _, _ in
      _ = exporter.export(spans: [TelemetryFixtures.spanData(), TelemetryFixtures.spanData()])
    }

    XCTAssertTrue(client.waitForAllCompletions())
    _ = reader.forceFlush()
    let seen = try XCTUnwrap(collector.exported.first { $0.name == "otlp.exporter.seen" })
    let seenPoint = try XCTUnwrap(seen.data.points.last as? LongPointData)
    // Failed sends are requeued and counted again on the next attempt.
    XCTAssertGreaterThanOrEqual(seenPoint.value, 2 * threads * iterations)
  }

  private final class CollectingMetricExporter: MetricExporter, @unchecked Sendable {
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
}

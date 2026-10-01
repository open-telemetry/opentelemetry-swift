//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import SharedTestUtils
import XCTest

final class PeriodicMetricReaderIntegrationTests: XCTestCase {
  private let exportInterval: TimeInterval = 0.05
  private let metricsPath = "/v1/metrics"
  private var meterProvider: MeterProviderSdk!
  private var testServer: HttpTestServer!

  override func setUp() {
    super.setUp()
    testServer = HttpTestServer()
    XCTAssertNoThrow(try testServer.start())
  }

  override func tearDown() {
    _ = meterProvider?.shutdown()
    meterProvider = nil
    testServer.stop()
    testServer = nil
    super.tearDown()
  }

  func testTimerKeepsEnqueueingWhileExportIsBlocked() {
    let exporter = CountingBlockingMetricExporter(aggregationTemporality: .delta)
    let reader = PeriodicMetricReaderBuilder(exporter: exporter)
      .setInterval(timeInterval: exportInterval)
      .build()
    meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: reader)
      .registerView(
        selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
        view: View.builder().build()
      )
      .build()
    let observableGauge = meterProvider
      .meterBuilder(name: "periodic-reader-integration")
      .build()
      .gaugeBuilder(name: "gauge")
      .buildWithCallback { measurement in
        measurement.record(value: 1)
      }

    exporter.waitUntilIsBlocked()
    XCTAssertEqual(exporter.exportCallCount, 1)

    Thread.sleep(forTimeInterval: exportInterval * 30)

    let blockedCallCount = exporter.exportCallCount
    XCTAssertEqual(blockedCallCount, 1)

    exporter.unblock()
    let drainStart = Date()
    let drainDeadline = drainStart.addingTimeInterval(0.3)
    while exporter.exportCallCount <= 10, Date() < drainDeadline {
      Thread.sleep(forTimeInterval: 0.01)
    }

    let elapsed = Date().timeIntervalSince(drainStart)
    let drainedCallCount = exporter.exportCallCount
    let capturedBatchCount = exporter.capturedBatches.count
    print(
      "PeriodicMetricReader calibration: blocked=\(blockedCallCount), "
        + "drained=\(drainedCallCount), capturedBatches=\(capturedBatchCount), elapsed=\(elapsed)"
    )
    XCTAssertGreaterThan(drainedCallCount, 10)
    XCTAssertLessThan(elapsed, 0.3)
    XCTAssertGreaterThan(capturedBatchCount, 8)
    withExtendedLifetime(observableGauge) {}
  }

  func testOtlpHttpExportWithPeriodicReader() {
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)\(metricsPath)")!
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint)
    let reader = PeriodicMetricReaderBuilder(exporter: exporter)
      .setInterval(timeInterval: 60)
      .build()
    meterProvider = MeterProviderSdk.builder()
      .registerMetricReader(reader: reader)
      .registerView(
        selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
        view: View.builder().build()
      )
      .build()
    let counter = meterProvider
      .meterBuilder(name: "otlp-periodic-reader-integration")
      .build()
      .counterBuilder(name: "requests")
      .build()

    counter.add(value: 1)
    XCTAssertEqual(meterProvider.forceFlush(), .success)

    let request = testServer.waitForRequest()
    XCTAssertNotNil(request)
    XCTAssertEqual(request?.head.method, .POST)
    XCTAssertEqual(request?.head.uri, metricsPath)
    XCTAssertFalse(request?.body?.isEmpty ?? true)
  }
}

private final class CountingBlockingMetricExporter: MetricExporter, @unchecked Sendable {
  private enum State {
    case waitingToBlock
    case blocked
    case unblocked
  }

  private let condition = NSCondition()
  private let aggregationTemporality: AggregationTemporality
  private var state = State.waitingToBlock
  private var callCount = 0
  private var batches = [[MetricData]]()

  var exportCallCount: Int {
    condition.withLock { callCount }
  }

  var capturedBatches: [[MetricData]] {
    condition.withLock { batches }
  }

  init(aggregationTemporality: AggregationTemporality) {
    self.aggregationTemporality = aggregationTemporality
  }

  func export(metrics: [MetricData]) -> ExportResult {
    condition.lock()
    callCount += 1
    batches.append(metrics)
    while state != .unblocked {
      state = .blocked
      condition.broadcast()
      condition.wait()
    }
    condition.unlock()
    return .success
  }

  func waitUntilIsBlocked() {
    condition.lock()
    while state != .blocked {
      condition.wait()
    }
    condition.unlock()
  }

  func unblock() {
    condition.lock()
    state = .unblocked
    condition.broadcast()
    condition.unlock()
  }

  func flush() -> ExportResult {
    .success
  }

  func shutdown() -> ExportResult {
    .success
  }

  func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    aggregationTemporality
  }
}

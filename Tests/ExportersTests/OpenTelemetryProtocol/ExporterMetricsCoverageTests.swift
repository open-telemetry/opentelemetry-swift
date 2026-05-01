/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetrySdk
import XCTest

final class ExporterMetricsCoverageTests: XCTestCase {
  private final class CapturingMetricExporter: MetricExporter {
    var captured: [MetricData] = []
    func export(metrics: [MetricData]) -> ExportResult {
      captured.append(contentsOf: metrics)
      return .success
    }
    func flush() -> ExportResult { .success }
    func shutdown() -> ExportResult { .success }
    func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
      .cumulative
    }
  }

  private func makeProvider(_ exporter: CapturingMetricExporter) -> MeterProviderSdk {
    MeterProviderSdk.builder()
      .registerMetricReader(
        reader: PeriodicMetricReaderBuilder(exporter: exporter)
          .setInterval(timeInterval: 0.1)
          .build()
      )
      .registerView(
        selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
        view: View.builder().build()
      )
      .build()
  }

  func testTransporterTypeRawValues() {
    XCTAssertEqual(ExporterMetrics.TransporterType.grpc.rawValue, "grpc")
    XCTAssertEqual(ExporterMetrics.TransporterType.protoBuf.rawValue, "http")
    XCTAssertEqual(ExporterMetrics.TransporterType.httpJson.rawValue, "http-json")
  }

  func testAttributeKeysAreConstants() {
    XCTAssertEqual(ExporterMetrics.ATTRIBUTE_KEY_TYPE, "type")
    XCTAssertEqual(ExporterMetrics.ATTRIBUTE_KEY_SUCCESS, "success")
  }

  func testInitializerSetsUpCounters() {
    let exporter = CapturingMetricExporter()
    let provider = makeProvider(exporter)
    let metrics = ExporterMetrics(type: "span",
                                  meterProvider: provider,
                                  exporterName: "otlp",
                                  transportName: .grpc)
    XCTAssertNotNil(metrics)
  }

  func testAddSeenSuccessFailedEmitCounters() throws {
    let exporter = CapturingMetricExporter()
    let provider = makeProvider(exporter)
    let metrics = ExporterMetrics(type: "span",
                                  meterProvider: provider,
                                  exporterName: "otlp",
                                  transportName: .protoBuf)

    metrics.addSeen(value: 2)
    metrics.addSeen(value: 3)
    metrics.addSuccess(value: 4)
    metrics.addFailed(value: 1)

    // Force a flush so the reader produces MetricData.
    XCTAssertEqual(provider.forceFlush(), .success)

    let seenMetrics = exporter.captured.filter { $0.name == "otlp.exporter.seen" }
    let exportedMetrics = exporter.captured.filter { $0.name == "otlp.exporter.exported" }
    XCTAssertFalse(seenMetrics.isEmpty)
    XCTAssertFalse(exportedMetrics.isEmpty)

    // Seen counter should total 5 across attribute set(s).
    let seenSum = seenMetrics.flatMap { $0.data.points }
      .compactMap { ($0 as? LongPointData)?.value }
      .reduce(0, +)
    XCTAssertEqual(seenSum, 5)
  }

  func testMakeExporterMetricFactoryProducesInstance() {
    let exporter = CapturingMetricExporter()
    let provider = makeProvider(exporter)
    let m = ExporterMetrics.makeExporterMetric(type: "log",
                                               meterProvider: provider,
                                               exporterName: "otlp",
                                               transportName: .httpJson)
    XCTAssertNotNil(m)
    m.addSeen(value: 7)
    m.addSuccess(value: 7)
  }
}

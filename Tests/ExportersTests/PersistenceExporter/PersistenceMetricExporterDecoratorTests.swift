/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class PersistenceMetricExporterDecoratorTests: XCTestCase {
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  class MetricExporterMock: MetricExporter {
    func flush() -> OpenTelemetrySdk.ExportResult {
      .success
    }

    func shutdown() -> OpenTelemetrySdk.ExportResult {
      .success
    }

    func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
      .cumulative
    }

    let onExport: ([MetricData]) -> ExportResult
    init(onExport: @escaping ([MetricData]) -> ExportResult) {
      self.onExport = onExport
    }

    func export(metrics: [MetricData]) -> ExportResult {
      return onExport(metrics)
    }
  }

  override func setUp() {
    super.setUp()
    temporaryDirectory.create()
  }

  override func tearDown() {
    temporaryDirectory.delete()
    super.tearDown()
  }

  func testWhenExportMetricIsCalled_thenMetricsAreExported() throws {
    let metricsExportExpectation = expectation(description: "metrics exported")
    let mockMetricExporter = MetricExporterMock(onExport: { metrics in
      metrics.forEach { metric in
        if metric.name == "MyCounter", metric.data.points.count == 1 {
          let pointData: LongPointData = metric.data.points[0] as! LongPointData
          if pointData.value == 100,
             pointData.attributes == ["labelKey": AttributeValue.string("labelValue")] {
            metricsExportExpectation.fulfill()
          }
        }
      }
      return .success
    })

    let persistenceMetricExporter =
      try PersistenceMetricExporterDecorator(metricExporter: mockMetricExporter,
                                             storageURL: temporaryDirectory.url,
                                             exportCondition: { return true },
                                             performancePreset: PersistencePerformancePreset.mockWith(storagePerformance: StoragePerformanceMock.writeEachObjectToNewFileAndReadAllFiles,
                                                                                                      synchronousWrite: true,
                                                                                                      exportPerformance: ExportPerformanceMock.veryQuick))

    let provider = MeterProviderSdk.builder().registerMetricReader(
      reader: PeriodicMetricReaderBuilder(
        exporter: persistenceMetricExporter
      ).setInterval(timeInterval: 1)
        .build()
    ).registerView(
      selector: InstrumentSelector.builder().setInstrument(
        name: ".*"
      ).build(),
      view: View.builder().build()
    ).build()

    let meter = provider.get(name: "MyMeter")

    let myCounter = meter.counterBuilder(name: "MyCounter").build()

    myCounter.add(value: 100, attributes: ["labelKey": AttributeValue.string("labelValue")])

    waitForExpectations(timeout: 10, handler: nil)
  }
}

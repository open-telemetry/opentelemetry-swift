/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

// a persistence exporter decorator for `Metric`.
// specialization of `PersistenceExporterDecorator` for `MetricExporter`.
public class PersistenceMetricExporterDecorator: MetricExporter {
  struct MetricDecoratedExporter: DecoratedExporter {
    typealias SignalType = MetricData

    private let metricExporter: any MetricExporter

    init(metricExporter: any MetricExporter) {
      self.metricExporter = metricExporter
    }

    func export(values: [MetricData]) -> DataExportStatus {
      let result = metricExporter.export(metrics: values)
      return DataExportStatus(needsRetry: result == .failure)
    }
  }

  private let metricExporter: MetricExporter
  private let persistenceExporter:
    PersistenceExporterDecorator<MetricDecoratedExporter>

  public init(metricExporter: MetricExporter,
              storageURL: URL,
              exportCondition: @escaping () -> Bool = { true },
              performancePreset: PersistencePerformancePreset = .default) throws {
    persistenceExporter =
      PersistenceExporterDecorator<MetricDecoratedExporter>(decoratedExporter: MetricDecoratedExporter(
        metricExporter: metricExporter),
      storageURL: storageURL,
      exportCondition: exportCondition,
      performancePreset: performancePreset)
    self.metricExporter = metricExporter
  }

  public func export(metrics: [MetricData])
    -> ExportResult {
    do {
      try persistenceExporter.export(values: metrics)

      return .success
    } catch {
      return .failure
    }
  }

  public func flush() -> OpenTelemetrySdk.ExportResult {
    persistenceExporter.flush()
    return metricExporter.flush()
  }

  public func shutdown() -> OpenTelemetrySdk.ExportResult {
    persistenceExporter.flush()
    return metricExporter.shutdown()
  }

  public func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    return metricExporter.getAggregationTemporality(for: instrument)
  }
}

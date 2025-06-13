/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

// a persistence exporter decorator for `Metric`.
// specialization of `PersistenceExporterDecorator` for `MetricExporter`.
public class PersistenceMetricExporterDecorator: StableMetricExporter {
  struct MetricDecoratedExporter: DecoratedExporter {
    typealias SignalType = StableMetricData

    private let metricExporter: StableMetricExporter

    init(metricExporter: StableMetricExporter) {
      self.metricExporter = metricExporter
    }

    func export(values: [StableMetricData]) -> DataExportStatus {
      let result = metricExporter.export(metrics: values)
      return DataExportStatus(needsRetry: result == .failure)
    }
  }

  private let metricExporter: StableMetricExporter
  private let persistenceExporter:
    PersistenceExporterDecorator<MetricDecoratedExporter>

  public init(metricExporter: StableMetricExporter,
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

  public func export(metrics: [StableMetricData])
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

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
    typealias SignalType = Metric

    private let metricExporter: MetricExporter

    init(metricExporter: MetricExporter) {
      self.metricExporter = metricExporter
    }

    func export(values: [Metric]) -> DataExportStatus {
      let result = metricExporter.export(metrics: values, shouldCancel: nil)
      return DataExportStatus(needsRetry: result == .failureRetryable)
    }
  }

  private let persistenceExporter:
    PersistenceExporterDecorator<MetricDecoratedExporter>

  public init(
    metricExporter: MetricExporter,
    storageURL: URL,
    exportCondition: @escaping () -> Bool = { true },
    performancePreset: PersistencePerformancePreset = .default
  ) throws {
    persistenceExporter =
      PersistenceExporterDecorator<MetricDecoratedExporter>(
        decoratedExporter: MetricDecoratedExporter(
          metricExporter: metricExporter),
        storageURL: storageURL,
        exportCondition: exportCondition,
        performancePreset: performancePreset)
  }

  public func export(metrics: [Metric], shouldCancel: (() -> Bool)?)
    -> MetricExporterResultCode {
    do {
      try persistenceExporter.export(values: metrics)

      return .success
    } catch {
      return .failureNotRetryable
    }
  }
}

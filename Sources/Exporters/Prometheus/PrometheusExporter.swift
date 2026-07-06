/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIOConcurrencyHelpers
import OpenTelemetrySdk

public final class PrometheusExporter: MetricExporter {
  let aggregationTemporalitySelector: AggregationTemporalitySelector

  public func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    return aggregationTemporalitySelector.getAggregationTemporality(for: instrument)
  }

  public func flush() -> OpenTelemetrySdk.ExportResult {
    // noop
    return .success
  }

  public func shutdown() -> OpenTelemetrySdk.ExportResult {
    // noop
    return .success
  }

  fileprivate let metricsLock = NIOLock()
  let options: PrometheusExporterOptions
  
  // nonisolated(unsafe) but protected by metricsLock
  private nonisolated(unsafe) var metrics = [MetricData]()

  public init(options: PrometheusExporterOptions, aggregationTemoralitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative()) {
    self.options = options
    aggregationTemporalitySelector = aggregationTemoralitySelector
  }

  public func export(metrics: [MetricData]) -> ExportResult {
    metricsLock.withLockVoid {
      self.metrics = metrics
    }
    return .success
  }

  public func getMetrics() -> [MetricData] {
    defer {
      metricsLock.unlock()
    }
    metricsLock.lock()
    return metrics
  }
}

public struct PrometheusExporterOptions: Sendable {
  var url: String

  public init(url: String) {
    self.url = url
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIOConcurrencyHelpers
import OpenTelemetrySdk

public class PrometheusExporter: StableMetricExporter {
  var aggregationTemporalitySelector: AggregationTemporalitySelector

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
  private var metrics = [StableMetricData]()

  public init(options: PrometheusExporterOptions, aggregationTemoralitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative()) {
    self.options = options
    aggregationTemporalitySelector = aggregationTemoralitySelector
  }

  public func export(metrics: [StableMetricData]) -> ExportResult {
    metricsLock.withLockVoid {
      self.metrics = metrics
    }
    return .success
  }
    
  public func getMetrics() -> [StableMetricData] {
    defer {
      metricsLock.unlock()
    }
    metricsLock.lock()
    return metrics
  }
}

public struct PrometheusExporterOptions {
  var url: String

  public init(url: String) {
    self.url = url
  }
}

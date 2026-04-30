/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreMetrics
import OpenTelemetryApi

public final class OpenTelemetrySwiftMetrics: MetricsFactory, @unchecked Sendable {
  let meter: any OpenTelemetryApi.Meter
  var metrics = [MetricKey: SwiftMetric]()
  let lock = Lock()

  public init(meter: any OpenTelemetryApi.Meter) {
    self.meter = meter
  }

  // MARK: - Make

  /// Counter: A counter is a cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero on
  /// restart. For example, you can use a counter to represent the number of requests served, tasks completed, or errors.
  public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
    lock.withLock {
      if let existing = metrics[.init(name: label, type: .counter)] {
        return existing as! CounterHandler
      }

      let metric = SwiftCounterMetric(name: label, labels: dimensions.dictionary, meter: meter)

      storeMetric(metric)
      return metric
    }
  }

  /// Recorder: A recorder collects observations within a time window (usually things like response sizes) and can provide aggregated information about the
  /// data sample, for example count, sum, min, max and various quantiles.
  ///
  /// Gauge: A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down. Gauges are typically used for measured values
  /// like temperatures or current memory usage, but also "counts" that can go up and down, like the number of active threads. Gauges are modeled as a
  /// Recorder with a sample size of 1 that does not perform any aggregation.
  public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
    lock.withLock {
      if let existing = metrics[.init(name: label, type: .histogram)] {
        return existing as! RecorderHandler
      }

      if let existing = metrics[.init(name: label, type: .gauge)] {
        return existing as! RecorderHandler
      }

      let metric: SwiftMetric & RecorderHandler = aggregate ?
        SwiftHistogramMetric(name: label, labels: dimensions.dictionary, meter: meter) :
        SwiftGaugeMetric(name: label, labels: dimensions.dictionary, meter: meter)

      storeMetric(metric)
      return metric
    }
  }

  /// Timer: A timer collects observations within a time window (usually things like request duration) and provides aggregated information about the data sample,
  /// for example min, max and various quantiles. It is similar to a Recorder but specialized for values that represent durations.
  public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
    lock.withLock {
      if let existing = metrics[.init(name: label, type: .summary)] {
        return existing as! TimerHandler
      }

      let metric = SwiftSummaryMetric(name: label, labels: dimensions.dictionary, meter: meter)

      storeMetric(metric)
      return metric
    }
  }

  private func storeMetric(_ metric: SwiftMetric) {
    metrics[.init(name: metric.metricName, type: metric.metricType)] = metric
  }

  // MARK: - Destroy

  public func destroyCounter(_ handler: CounterHandler) {
    destroyMetric(handler as? SwiftMetric)
  }

  public func destroyRecorder(_ handler: RecorderHandler) {
    destroyMetric(handler as? SwiftMetric)
  }

  public func destroyTimer(_ handler: TimerHandler) {
    destroyMetric(handler as? SwiftMetric)
  }

  private func destroyMetric(_ metric: SwiftMetric?) {
    lock.withLock {
      if let name = metric?.metricName, let type = metric?.metricType {
        metrics.removeValue(forKey: .init(name: name, type: type))
      }
    }
  }
}

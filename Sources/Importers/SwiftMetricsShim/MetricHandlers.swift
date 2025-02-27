/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreMetrics
import OpenTelemetryApi

class SwiftCounterMetric: CounterHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .counter
  let counter: AnyCounterMetric<Int>
  let labels: [String: String]

  required init(name: String, labels: [String: String], meter: OpenTelemetryApi.Meter) {
    metricName = name
    counter = meter.createIntCounter(name: name, monotonic: true)
    self.labels = labels
  }

  func increment(by: Int64) {
    counter.add(value: Int(by), labels: labels)
  }

  func reset() {}
}

class SwiftGaugeMetric: RecorderHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .gauge
  let counter: AnyCounterMetric<Double>
  let labels: [String: String]

  required init(name: String, labels: [String: String], meter: OpenTelemetryApi.Meter) {
    metricName = name
    counter = meter.createDoubleCounter(name: name, monotonic: false)
    self.labels = labels
  }

  func record(_ value: Int64) {
    counter.add(value: Double(value), labels: labels)
  }

  func record(_ value: Double) {
    counter.add(value: value, labels: labels)
  }
}

class SwiftHistogramMetric: RecorderHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .histogram
  let measure: AnyMeasureMetric<Double>
  let labels: [String: String]

  required init(name: String, labels: [String: String], meter: OpenTelemetryApi.Meter) {
    metricName = name
    measure = meter.createDoubleMeasure(name: name)
    self.labels = labels
  }

  func record(_ value: Int64) {
    measure.record(value: Double(value), labels: labels)
  }

  func record(_ value: Double) {
    measure.record(value: value, labels: labels)
  }
}

class SwiftSummaryMetric: TimerHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .summary
  let measure: AnyMeasureMetric<Double>
  let labels: [String: String]

  required init(name: String, labels: [String: String], meter: OpenTelemetryApi.Meter) {
    metricName = name
    measure = meter.createDoubleMeasure(name: name)
    self.labels = labels
  }

  func recordNanoseconds(_ duration: Int64) {
    measure.record(value: Double(duration), labels: labels)
  }
}

protocol SwiftMetric {
  var metricName: String { get }
  var metricType: MetricType { get }
  init(name: String, labels: [String: String], meter: OpenTelemetryApi.Meter)
}

enum MetricType: String {
  case counter
  case histogram
  case gauge
  case summary
}

struct MetricKey: Hashable {
  let name: String
  let type: MetricType
}

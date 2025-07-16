/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreMetrics
import OpenTelemetryApi

class SwiftCounterMetric: CounterHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .counter
  var counter: LongCounter
  let labels: [String: AttributeValue]

  required init(name: String,
                labels: [String: String],
                meter: any OpenTelemetryApi.Meter) {
    metricName = name
    counter = meter.counterBuilder(name: name).build()
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func increment(by: Int64) {
    counter.add(value: Int(by), attributes: labels)
  }

  func reset() {}
}

class SwiftGaugeMetric: RecorderHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .gauge
  var counter: DoubleGauge
  let labels: [String: AttributeValue]

  required init(name: String,
                labels: [String: String],
                meter: any OpenTelemetryApi.Meter) {
    metricName = name
    counter = meter.gaugeBuilder(name: name).build()
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func record(_ value: Int64) {
    counter.record(value: Double(value), attributes: labels)
  }

  func record(_ value: Double) {
    counter.record(value: value, attributes: labels)
  }
}

class SwiftHistogramMetric: RecorderHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .histogram
  var measure: DoubleHistogram
  let labels: [String: AttributeValue]

  required init(name: String, labels: [String: String], meter: any OpenTelemetryApi.Meter) {
    metricName = name
    measure = meter.histogramBuilder(name: name).build()
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func record(_ value: Int64) {
    measure.record(value: Double(value), attributes: labels)
  }

  func record(_ value: Double) {
    measure.record(value: value, attributes: labels)
  }
}

class SwiftSummaryMetric: TimerHandler, SwiftMetric {
  let metricName: String
  let metricType: MetricType = .summary
  var measure: DoubleCounter
  let labels: [String: AttributeValue]

  required init(name: String, labels: [String: String], meter: any OpenTelemetryApi.Meter) {
    metricName = name
    measure = meter.counterBuilder(name: name).ofDoubles().build()
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func recordNanoseconds(_ duration: Int64) {
    measure.add(value: Double(duration), attributes: labels)
  }
}

protocol SwiftMetric {
  var metricName: String { get }
  var metricType: MetricType { get }
  init(name: String, labels: [String: String], meter: any OpenTelemetryApi.Meter)
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

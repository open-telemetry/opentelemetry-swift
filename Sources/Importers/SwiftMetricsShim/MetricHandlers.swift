/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import CoreMetrics
import OpenTelemetryApi

final class SwiftCounterMetric: CounterHandler, SwiftMetric, @unchecked Sendable {
  let metricName: String
  let metricType: MetricType = .counter
  let counter: Locked<LongCounter>
  let labels: [String: AttributeValue]

  required init(name: String,
                labels: [String: String],
                meter: any OpenTelemetryApi.Meter) {
    metricName = name
    counter = .init(initialValue: meter.counterBuilder(name: name).build())
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func increment(by: Int64) {
    counter.protectedValue.add(value: Int(by), attributes: labels)
  }

  func reset() {}
}

final class SwiftGaugeMetric: RecorderHandler, SwiftMetric, @unchecked Sendable {
  let metricName: String
  let metricType: MetricType = .gauge
  let counter: Locked<DoubleGauge>
  let labels: [String: AttributeValue]

  required init(name: String,
                labels: [String: String],
                meter: any OpenTelemetryApi.Meter) {
    metricName = name
    counter = .init(initialValue: meter.gaugeBuilder(name: name).build())
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func record(_ value: Int64) {
    counter.protectedValue.record(value: Double(value), attributes: labels)
  }

  func record(_ value: Double) {
    counter.protectedValue.record(value: value, attributes: labels)
  }
}

final class SwiftHistogramMetric: RecorderHandler, SwiftMetric, @unchecked Sendable {
  let metricName: String
  let metricType: MetricType = .histogram
  let measure: Locked<DoubleHistogram>
  let labels: [String: AttributeValue]

  required init(name: String, labels: [String: String], meter: any OpenTelemetryApi.Meter) {
    metricName = name
    measure = .init(initialValue: meter.histogramBuilder(name: name).build())
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func record(_ value: Int64) {
    measure.protectedValue.record(value: Double(value), attributes: labels)
  }

  func record(_ value: Double) {
    measure.protectedValue.record(value: value, attributes: labels)
  }
}

final class SwiftSummaryMetric: TimerHandler, SwiftMetric, @unchecked Sendable {
  let metricName: String
  let metricType: MetricType = .summary
  let measure: Locked<DoubleCounter>
  let labels: [String: AttributeValue]

  required init(name: String, labels: [String: String], meter: any OpenTelemetryApi.Meter) {
    metricName = name
    measure = .init(initialValue: meter.counterBuilder(name: name).ofDoubles().build())
    self.labels = labels.mapValues { value in
      return AttributeValue.string(value)
    }
  }

  func recordNanoseconds(_ duration: Int64) {
    measure.protectedValue.add(value: Double(duration), attributes: labels)
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

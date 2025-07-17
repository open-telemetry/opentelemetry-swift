/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public enum PrometheusExporterExtensions {
  static let prometheusCounterType = "counter"
  static let prometheusGaugeType = "gauge"
  static let prometheusSummaryType = "summary"
  static let prometheusSummarySumPostFix = "_sum"
  static let prometheusSummaryCountPostFix = "_count"
  static let prometheusSummaryQuantileLabelName = "quantile"
  static let prometheusSummaryQuantileLabelValueForMin = "0"
  static let prometheusSummaryQuantileLabelValueForMax = "1"
  static let prometheusHistogramType = "histogram"
  static let prometheusHistogramSumPostFix = "_sum"
  static let prometheusHistogramCountPostFix = "_count"
  static let prometheusHistogramBucketPostFix = "_bucket"
  static let prometheusHistogramLeLabelName = "le"

  public static func writeMetricsCollection(exporter: PrometheusExporter) -> String {
    var output = ""
    let metrics = exporter.getMetrics()
    let now = String(Int64((Date().timeIntervalSince1970 * 1000.0).rounded()))

    metrics.forEach { metric in
      let prometheusMetric = PrometheusMetric(name: metric.name, description: metric.description)
      metric.data.points.forEach { metricData in
        let labels = metricData.attributes
        switch metric.type {
        case .DoubleSum:
          guard let sum = metricData as? DoublePointData else {
            break
          }
          output += PrometheusExporterExtensions
            .writeSum(
              prometheusMetric: prometheusMetric,
              timeStamp: now,
              labels: labels.mapValues { value in
                value.description
              },
              doubleValue: sum.value
            )
        case .LongSum:
          guard let sum = metricData as? LongPointData else {
            break
          }
          output += PrometheusExporterExtensions
            .writeSum(
              prometheusMetric: prometheusMetric,
              timeStamp: now,
              labels: labels.mapValues { value in
                value.description
              },
              doubleValue: Double(sum.value)
            )
        case .DoubleGauge:
          guard let gauge = metricData as? DoublePointData else { break }
          output += PrometheusExporterExtensions
            .writeGauge(
              prometheusMetric: prometheusMetric,
              timeStamp: now,
              labels: labels.mapValues { value in
                value.description
              },
              doubleValue: gauge.value
            )
        case .LongGauge:
          guard let gauge = metricData as? LongPointData else { break }
          output += PrometheusExporterExtensions
            .writeGauge(
              prometheusMetric: prometheusMetric,
              timeStamp: now,
              labels: labels.mapValues { value in
                value.description
              },
              doubleValue: Double(gauge.value)
            )
        case .Histogram:
          guard let histogram = metricData as? HistogramPointData else { break }
          let count = histogram.count
          let sum = histogram.sum
          let bucketsBoundaries = histogram.boundaries
          let bucketsCounts = histogram.counts
          output += PrometheusExporterExtensions
            .writeHistogram(
              prometheusMetric: prometheusMetric,
              timeStamp: now,
              labels: labels.mapValues { value in
                value.description
              },
              metricName: metric.name,
              sum: Double(sum),
              count: Int(count),
              bucketsBoundaries: bucketsBoundaries,
              bucketsCounts: bucketsCounts
            )
        case .ExponentialHistogram:
          guard let histogram = metricData as? HistogramPointData else { break }
          let count = histogram.count
          let sum = histogram.sum
          let bucketsBoundaries = histogram.boundaries
          let bucketsCounts = histogram.counts
          output += PrometheusExporterExtensions
            .writeHistogram(
              prometheusMetric: prometheusMetric,
              timeStamp: now,
              labels: labels.mapValues { value in
                value.description
              },
              metricName: metric.name,
              sum: Double(sum),
              count: Int(count),
              bucketsBoundaries: bucketsBoundaries,
              bucketsCounts: bucketsCounts
            )
        case .Summary:
          guard let summary = metricData as? SummaryPointData else { break }
          let count = summary.count
          let sum = summary.sum
          let min = summary.values.max(by: { a, b in
            a.value < b.value
          })?.value ?? 0.0
          let max = summary.values.max { a, b in
            a.value > b.value
          }?.value ?? 0.0
          output += PrometheusExporterExtensions
            .writeSummary(
              prometheusMetric: prometheusMetric,
              timeStamp: now,
              labels: labels.mapValues { value in
                value.description
              },
              metricName: metric.name,
              sum: Double(sum),
              count: Int(count),
              min: Double(min),
              max: Double(max)
            )
        }
      }
    }

    return output
  }

  private static func writeSum(prometheusMetric: PrometheusMetric, timeStamp: String, labels: [String: String], doubleValue: Double) -> String {
    var prometheusMetric = prometheusMetric
    prometheusMetric.type = prometheusCounterType
    let metricValue = PrometheusValue(labels: labels, value: doubleValue)
    prometheusMetric.values.append(metricValue)
    return prometheusMetric.write(timeStamp: timeStamp)
  }

  private static func writeGauge(prometheusMetric: PrometheusMetric, timeStamp: String, labels: [String: String], doubleValue: Double) -> String {
    var prometheusMetric = prometheusMetric
    prometheusMetric.type = prometheusGaugeType
    let metricValue = PrometheusValue(labels: labels, value: doubleValue)
    prometheusMetric.values.append(metricValue)
    return prometheusMetric.write(timeStamp: timeStamp)
  }

  private static func writeSummary(prometheusMetric: PrometheusMetric, timeStamp: String, labels: [String: String], metricName: String, sum: Double, count: Int, min: Double, max: Double) -> String {
    var prometheusMetric = prometheusMetric
    prometheusMetric.type = prometheusSummaryType
    labels.forEach {
      prometheusMetric.values.append(PrometheusValue(name: metricName + prometheusSummarySumPostFix, labels: [$0.key: $0.value], value: sum))
      prometheusMetric.values.append(PrometheusValue(name: metricName + prometheusSummaryCountPostFix, labels: [$0.key: $0.value], value: Double(count)))
      prometheusMetric.values.append(PrometheusValue(name: metricName,
                                                     labels: [$0.key: $0.value,
                                                              prometheusSummaryQuantileLabelName: prometheusSummaryQuantileLabelValueForMin],
                                                     value: min))
      prometheusMetric.values.append(PrometheusValue(name: metricName,
                                                     labels: [$0.key: $0.value,
                                                              prometheusSummaryQuantileLabelName: prometheusSummaryQuantileLabelValueForMax],
                                                     value: max))
    }
    return prometheusMetric.write(timeStamp: timeStamp)
  }

  private static func writeHistogram(prometheusMetric: PrometheusMetric, timeStamp: String, labels: [String: String], metricName: String, sum: Double, count: Int, bucketsBoundaries: [Double], bucketsCounts: [Int]) -> String {
    var prometheusMetric = prometheusMetric
    prometheusMetric.type = prometheusHistogramType
    labels.forEach {
      prometheusMetric.values.append(PrometheusValue(name: metricName + prometheusHistogramSumPostFix, labels: [$0.key: $0.value], value: sum))
      prometheusMetric.values.append(PrometheusValue(name: metricName + prometheusHistogramCountPostFix, labels: [$0.key: $0.value], value: Double(count)))
      for i in 0 ..< bucketsBoundaries.count {
        prometheusMetric.values.append(PrometheusValue(name: metricName,
                                                       labels: [$0.key: $0.value,
                                                                prometheusHistogramLeLabelName: String(format: "%f", bucketsBoundaries[i])],
                                                       value: Double(bucketsCounts[i])))
      }
      prometheusMetric.values.append(PrometheusValue(name: metricName,
                                                     labels: [$0.key: $0.value,
                                                              prometheusHistogramLeLabelName: "+Inf"],
                                                     value: Double(bucketsCounts[bucketsBoundaries.count])))
    }
    return prometheusMetric.write(timeStamp: timeStamp)
  }
}

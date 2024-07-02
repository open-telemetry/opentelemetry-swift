/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public enum PrometheusExporterExtensions {
    static let prometheusCounterType = "counter"
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
        let metrics = exporter.getAndClearMetrics()
        let now = String(Int64((Date().timeIntervalSince1970 * 1000.0).rounded()))

        metrics.forEach { metric in
            let prometheusMetric = PrometheusMetric(name: metric.name, description: metric.description)
            metric.data.forEach { metricData in
                let labels = metricData.labels
                switch metric.aggregationType {
                case .doubleSum:
                    let sum = metricData as! SumData<Double>
                    output += PrometheusExporterExtensions.writeSum(prometheusMetric: prometheusMetric, timeStamp: now, labels: labels, doubleValue: sum.sum)
                case .intSum:
                    let sum = metricData as! SumData<Int>
                    output += PrometheusExporterExtensions.writeSum(prometheusMetric: prometheusMetric, timeStamp: now, labels: labels, doubleValue: Double(sum.sum))
                case .doubleSummary, .doubleGauge:
                    let summary = metricData as! SummaryData<Double>
                    let count = summary.count
                    let sum = summary.sum
                    let min = summary.min
                    let max = summary.max
                    output += PrometheusExporterExtensions.writeSummary(prometheusMetric: prometheusMetric, timeStamp: now, labels: labels, metricName: metric.name, sum: sum, count: count, min: min, max: max)
                case .intSummary, .intGauge:
                    let summary = metricData as! SummaryData<Int>
                    let count = summary.count
                    let sum = summary.sum
                    let min = summary.min
                    let max = summary.max
                    output += PrometheusExporterExtensions.writeSummary(prometheusMetric: prometheusMetric, timeStamp: now, labels: labels, metricName: metric.name, sum: Double(sum), count: count, min: Double(min), max: Double(max))
                case .intHistogram:
                    let histogram = metricData as! HistogramData<Int>
                    let count = histogram.count
                    let sum = histogram.sum
                    let bucketsBoundaries = histogram.buckets.boundaries.map{Double($0)}
                    let bucketsCounts = histogram.buckets.counts
                    output += PrometheusExporterExtensions.writeHistogram(prometheusMetric: prometheusMetric, timeStamp: now, labels: labels, metricName: metric.name, sum: Double(sum), count: count, bucketsBoundaries: bucketsBoundaries, bucketsCounts: bucketsCounts)
                case .doubleHistogram:
                    let histogram = metricData as! HistogramData<Double>
                    let count = histogram.count
                    let sum = histogram.sum
                    let bucketsBoundaries = histogram.buckets.boundaries
                    let bucketsCounts = histogram.buckets.counts
                    output += PrometheusExporterExtensions.writeHistogram(prometheusMetric: prometheusMetric, timeStamp: now, labels: labels, metricName: metric.name, sum: Double(sum), count: count, bucketsBoundaries: bucketsBoundaries, bucketsCounts: bucketsCounts)
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

    private static func writeHistogram(prometheusMetric: PrometheusMetric, timeStamp: String, labels: [String: String], metricName: String, sum: Double, count: Int, bucketsBoundaries: Array<Double>, bucketsCounts: Array<Int>) -> String {
        var prometheusMetric = prometheusMetric
        prometheusMetric.type = prometheusHistogramType
        labels.forEach {
            prometheusMetric.values.append(PrometheusValue(name: metricName + prometheusHistogramSumPostFix, labels: [$0.key: $0.value], value: sum))
            prometheusMetric.values.append(PrometheusValue(name: metricName + prometheusHistogramCountPostFix, labels: [$0.key: $0.value], value: Double(count)))
            for i in 0..<bucketsBoundaries.count {
                prometheusMetric.values.append(PrometheusValue(name: metricName,
                                                               labels: [$0.key: $0.value,
                                                                        prometheusHistogramLeLabelName: String(format:"%f", bucketsBoundaries[i])],
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

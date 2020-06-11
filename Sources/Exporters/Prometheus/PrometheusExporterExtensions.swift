// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import OpenTelemetrySdk

public struct PrometheusExporterExtensions {
    static let prometheusCounterType = "counter"
    static let prometheusSummaryType = "summary"
    static let prometheusSummarySumPostFix = "_sum"
    static let prometheusSummaryCountPostFix = "_count"
    static let prometheusSummaryQuantileLabelName = "quantile"
    static let prometheusSummaryQuantileLabelValueForMin = "0"
    static let prometheusSummaryQuantileLabelValueForMax = "1"

    static func writeMetricsCollection(exporter: PrometheusExporter) -> String {
        var output = ""
        let metrics = exporter.getAndClearMetrics()
        metrics.forEach { metric in
            let prometheusMetric = PrometheusMetric(name: metric.name, description: metric.description)
            metric.data.forEach { metricData in
                let labels = metricData.labels
                switch metric.aggregationType {
                case .doubleSum:
                    let sum = metricData as! SumData<Double>
                    output += PrometheusExporterExtensions.writeSum(prometheusMetric: prometheusMetric, labels: labels, doubleValue: sum.sum)
                case .intSum:
                    let sum = metricData as! SumData<Int>
                    output += PrometheusExporterExtensions.writeSum(prometheusMetric: prometheusMetric, labels: labels, doubleValue: Double(sum.sum))
                case .doubleSummary:
                    let summary = metricData as! SummaryData<Double>
                    let count = summary.count
                    let sum = summary.sum
                    let min = summary.min
                    let max = summary.max
                    output += PrometheusExporterExtensions.writeSummary(prometheusMetric: prometheusMetric, labels: labels, metricName: metric.name, sum: sum, count: count, min: min, max: max)
                case .intSummary:
                    let summary = metricData as! SummaryData<Int>
                    let count = summary.count
                    let sum = summary.sum
                    let min = summary.min
                    let max = summary.max
                    output += PrometheusExporterExtensions.writeSummary(prometheusMetric: prometheusMetric, labels: labels, metricName: metric.name, sum: Double(sum), count: count, min: Double(min), max: Double(max))
                }
            }
        }

        return output
    }

    private static func writeSum(prometheusMetric: PrometheusMetric, labels: [String: String], doubleValue: Double) -> String {
        var prometheusMetric = prometheusMetric
        prometheusMetric.type = prometheusCounterType
        let metricValue = PrometheusValue(labels: labels, value: doubleValue)
        prometheusMetric.values.append(metricValue)
        return prometheusMetric.write()
    }

    private static func writeSummary(prometheusMetric: PrometheusMetric, labels: [String: String], metricName: String, sum: Double, count: Int, min: Double, max: Double) -> String {
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
        return prometheusMetric.write()
    }
}

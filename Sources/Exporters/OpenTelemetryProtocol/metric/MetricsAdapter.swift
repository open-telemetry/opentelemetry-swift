/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct MetricsAdapter {
    static func toProtoResourceMetrics(metricDataList: [Metric]) -> [Opentelemetry_Proto_Metrics_V1_ResourceMetrics] {
        let resourceAndScopeMap = groupByResouceAndScope(metricDataList: metricDataList)
        var resourceMetrics = [Opentelemetry_Proto_Metrics_V1_ResourceMetrics]()

        resourceAndScopeMap.forEach { resMap in
            var instrumentationScopeMetrics = [Opentelemetry_Proto_Metrics_V1_ScopeMetrics]()
            resMap.value.forEach { instScope in
                var protoInst =
                Opentelemetry_Proto_Metrics_V1_ScopeMetrics()
                protoInst.scope =
                    CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: instScope.key)
                instScope.value.forEach {
                    protoInst.metrics.append($0)
                }
                instrumentationScopeMetrics.append(protoInst)
            }
            var resourceMetric = Opentelemetry_Proto_Metrics_V1_ResourceMetrics()
            resourceMetric.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
            resourceMetric.scopeMetrics.append(contentsOf: instrumentationScopeMetrics)
            resourceMetrics.append(resourceMetric)
        }

        return resourceMetrics
    }

    private static func groupByResouceAndScope(metricDataList: [Metric]) -> [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]] {
        var results = [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]]()

        metricDataList.forEach {
            if let metric = toProtoMetric(metric: $0) {
                results[$0.resource, default: [InstrumentationScopeInfo: [Opentelemetry_Proto_Metrics_V1_Metric]]()][$0.instrumentationScopeInfo, default: [Opentelemetry_Proto_Metrics_V1_Metric]()]
                    .append(metric)
            }
        }

        return results
    }

    static func toProtoMetric(metric: Metric) -> Opentelemetry_Proto_Metrics_V1_Metric? {
        var protoMetric = Opentelemetry_Proto_Metrics_V1_Metric()
        protoMetric.name = metric.name
        protoMetric.unit = "unit"
        protoMetric.description_p = metric.description
        if metric.data.isEmpty { return nil }

        metric.data.forEach {
            switch metric.aggregationType {
            case .doubleGauge:
                guard let gaugeData = $0 as? SumData<Double> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()

                protoDataPoint.timeUnixNano = gaugeData.timestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.startTimeUnixNano = gaugeData.startTimestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.value = .asDouble(gaugeData.sum)
                gaugeData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }

                protoMetric.gauge.dataPoints.append(protoDataPoint)
            case .intGauge:
                guard let gaugeData = $0 as? SumData<Int> else {
                    break
                }

                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()

                protoDataPoint.value = .asInt(Int64(exactly: gaugeData.sum)!)
                protoDataPoint.timeUnixNano = gaugeData.timestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.startTimeUnixNano = gaugeData.startTimestamp.timeIntervalSince1970.toNanoseconds
                gaugeData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }

                protoMetric.gauge.dataPoints.append(protoDataPoint)
            case .doubleSum:
                guard let sumData = $0 as? SumData<Double> else {
                    break
                }

                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()

                protoDataPoint.value = .asDouble(sumData.sum)
                protoDataPoint.timeUnixNano = sumData.timestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.startTimeUnixNano = sumData.startTimestamp.timeIntervalSince1970.toNanoseconds
                sumData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }

                protoMetric.sum.aggregationTemporality = .cumulative
                protoMetric.sum.dataPoints.append(protoDataPoint)
            case .doubleSummary:

                guard let summaryData = $0 as? SummaryData<Double> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_SummaryDataPoint()

                protoDataPoint.sum = summaryData.sum
                protoDataPoint.count = UInt64(summaryData.count)

                protoDataPoint.startTimeUnixNano = summaryData.startTimestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.timeUnixNano = summaryData.timestamp.timeIntervalSince1970.toNanoseconds

                summaryData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }

                protoMetric.summary.dataPoints.append(protoDataPoint)
            case .intSum:
                guard let sumData = $0 as? SumData<Int> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_NumberDataPoint()

                protoDataPoint.value = .asInt(Int64(sumData.sum))
                protoDataPoint.timeUnixNano = sumData.timestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.startTimeUnixNano = sumData.startTimestamp.timeIntervalSince1970.toNanoseconds
                sumData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()

                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }

                protoMetric.sum.aggregationTemporality = .cumulative
                protoMetric.sum.dataPoints.append(protoDataPoint)
            case .intSummary:
                guard let summaryData = $0 as? SummaryData<Int> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_SummaryDataPoint()

                protoDataPoint.sum = Double(summaryData.sum)
                protoDataPoint.count = UInt64(summaryData.count)
                protoDataPoint.startTimeUnixNano = summaryData.startTimestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.timeUnixNano = summaryData.timestamp.timeIntervalSince1970.toNanoseconds

                summaryData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }

                protoMetric.summary.dataPoints.append(protoDataPoint)
            case .intHistogram:
                guard let histogramData = $0 as? HistogramData<Int> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_HistogramDataPoint()

                protoDataPoint.sum = Double(histogramData.sum)
                protoDataPoint.count = UInt64(histogramData.count)
                protoDataPoint.startTimeUnixNano = histogramData.startTimestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.timeUnixNano = histogramData.timestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.explicitBounds = histogramData.buckets.boundaries.map { Double($0) }
                protoDataPoint.bucketCounts = histogramData.buckets.counts.map { UInt64($0) }
                
                histogramData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }
                
                protoMetric.histogram.aggregationTemporality = .cumulative
                protoMetric.histogram.dataPoints.append(protoDataPoint)
            case .doubleHistogram:
                guard let histogramData = $0 as? HistogramData<Double> else {
                    break
                }
                var protoDataPoint = Opentelemetry_Proto_Metrics_V1_HistogramDataPoint()
                protoDataPoint.sum = Double(histogramData.sum)
                protoDataPoint.count = UInt64(histogramData.count)
                protoDataPoint.startTimeUnixNano = histogramData.startTimestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.timeUnixNano = histogramData.timestamp.timeIntervalSince1970.toNanoseconds
                protoDataPoint.explicitBounds = histogramData.buckets.boundaries.map { Double($0) }
                protoDataPoint.bucketCounts = histogramData.buckets.counts.map { UInt64($0) }
                
                histogramData.labels.forEach {
                    var kvp = Opentelemetry_Proto_Common_V1_KeyValue()
                    kvp.key = $0.key
                    kvp.value.stringValue = $0.value
                    protoDataPoint.attributes.append(kvp)
                }
                
                protoMetric.histogram.aggregationTemporality = .cumulative
                protoMetric.histogram.dataPoints.append(protoDataPoint)
            }
        }
        return protoMetric
    }
}

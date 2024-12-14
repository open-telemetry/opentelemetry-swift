/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

internal class MetricsExporter {
    let metricsDirectory = "com.otel.datadog.metrics/v1"
    let configuration: ExporterConfiguration
    let metricsStorage: FeatureStorage
    let metricsUpload: FeatureUpload

    init(config: ExporterConfiguration) throws {
        configuration = config

        let filesOrchestrator = FilesOrchestrator(
            directory: try Directory(withSubdirectoryPath: metricsDirectory),
            performance: configuration.performancePreset,
            dateProvider: SystemDateProvider()
        )

        let dataFormat = DataFormat(prefix: "{ \"series\": [", suffix: "]}", separator: ",\n")

        let spanFileWriter = FileWriter(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator
        )

        let spanFileReader = FileReader(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator
        )

        metricsStorage = FeatureStorage(writer: spanFileWriter, reader: spanFileReader)

        let requestBuilder = RequestBuilder(
            url: configuration.endpoint.metricsURL,
            queryItems: [],
            headers: [
                .contentTypeHeader(contentType: .textPlainUTF8),
                .userAgentHeader(
                    appName: configuration.applicationName,
                    appVersion: configuration.version,
                    device: Device.current
                ),
                .ddAPIKeyHeader(apiKey: configuration.apiKey),
                .ddEVPOriginHeader(source: configuration.source),
                .ddEVPOriginVersionHeader(version: configuration.version),
                .ddRequestIDHeader()
            ]
        )

        metricsUpload = FeatureUpload(featureName: "metricsUpload",
                                      storage: metricsStorage,
                                      requestBuilder: requestBuilder,
                                      performance: configuration.performancePreset,
                                      uploadCondition: configuration.uploadCondition)
    }

    func exportMetric(metric: Metric) {
        var tags = [String]()
        let points: [DDMetricPoint] = metric.data.map { metricData in
            let labels = metricData.labels
            tags.append(contentsOf: MetricUtils.getTags(labels: labels))
            switch metric.aggregationType {
            case .doubleSum:
                let sum = metricData as! SumData<Double>
                return DDMetricPoint(timestamp: metricData.timestamp, value: sum.sum)
            case .intSum:
                let sum = metricData as! SumData<Int>
                return DDMetricPoint(timestamp: metricData.timestamp, value: Double(sum.sum))
            case .doubleSummary, .doubleGauge:
                let summary = metricData as! SummaryData<Double>
                return DDMetricPoint(timestamp: metricData.timestamp, value: summary.sum)
            case .intSummary, .intGauge:
                let summary = metricData as! SummaryData<Int>
                return DDMetricPoint(timestamp: metricData.timestamp, value: Double(summary.sum))
            case .intHistogram:
                let histogram = metricData as! HistogramData<Int>
                return DDMetricPoint(timestamp: metricData.timestamp, value: Double(histogram.sum))
            case .doubleHistogram:
                let histogram = metricData as! HistogramData<Double>
                return DDMetricPoint(timestamp: metricData.timestamp, value: histogram.sum)
            }
        }

        let name = MetricUtils.getName(metric: metric, configuration: configuration)
        let type: String? = MetricUtils.getType(metric: metric)
        let host = configuration.hostName
        let interval: Int64? = nil

        let metric = DDMetric(name: name, points: points, type: type, host: host, interval: interval, tags: tags)

        if configuration.performancePreset.synchronousWrite {
            metricsStorage.writer.writeSync(value: metric)
        } else {
            metricsStorage.writer.write(value: metric)
        }
    }
}

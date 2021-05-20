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
    let metricsStorageQueue = DispatchQueue(label: "com.otel.datadog.metricswriter", target: .global(qos: .userInteractive))

    let metricsUpload: FeatureUpload
    let metricsUploadQueue = DispatchQueue(label: "com.otel.datadog.metricsupload", target: .global(qos: .userInteractive))

    init(config: ExporterConfiguration) throws {
        guard let apiKey = config.apiKey else {
            throw ExporterError(description: "Metrics Exporter need an api key")
        }

        self.configuration = config

        let filesOrchestrator = FilesOrchestrator(
            directory: try Directory(withSubdirectoryPath: metricsDirectory),
            performance: configuration.performancePreset,
            dateProvider: SystemDateProvider()
        )

        let dataFormat = DataFormat(prefix: "{ \"series\": [", suffix: "]}", separator: ",\n")

        let spanFileWriter = FileWriter(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator,
            queue: metricsStorageQueue
        )

        let spanFileReader = FileReader(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator,
            queue: metricsUploadQueue
        )

        metricsStorage = FeatureStorage(writer: spanFileWriter, reader: spanFileReader)

        let urlProvider = UploadURLProvider(
            urlWithClientToken: configuration.endpoint.metricsURL,
            queryItemProviders: [
                .apiKey(apiKey: apiKey),
            ]
        )

        let httpHeaders = HTTPHeaders(headers: [
            .contentTypeHeader(contentType: .textPlainUTF8),
            .userAgentHeader(
                appName: configuration.applicationName,
                appVersion: configuration.version,
                device: Device.current
            ),
        ])

        metricsUpload = FeatureUpload(featureName: "metricsUpload",
                                      storage: metricsStorage,
                                      uploadHTTPHeaders: httpHeaders,
                                      uploadURLProvider: urlProvider,
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
                case .doubleSummary:
                    let summary = metricData as! SummaryData<Double>
                    return DDMetricPoint(timestamp: metricData.timestamp, value: summary.sum)
                case .intSummary:
                    let summary = metricData as! SummaryData<Int>
                    return DDMetricPoint(timestamp: metricData.timestamp, value: Double(summary.sum))
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

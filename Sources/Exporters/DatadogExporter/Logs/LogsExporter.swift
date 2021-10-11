/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

internal enum LogLevel: Int, Codable {
    case debug
    case info
    case notice
    case warn
    case error
    case critical
}

internal class LogsExporter {
    let logsDirectory = "com.otel.datadog.logs/v1"

    let configuration: ExporterConfiguration

    let logsStorage: FeatureStorage
    let logsStorageQueue = DispatchQueue(label: "com.otel.datadog.logswriter", target: .global(qos: .userInteractive))

    let logsUpload: FeatureUpload
    let logsUploadQueue = DispatchQueue(label: "com.otel.datadog.logsupload", target: .global(qos: .userInteractive))

    init(config: ExporterConfiguration) throws {
        self.configuration = config

        let filesOrchestrator = FilesOrchestrator(
            directory: try Directory(withSubdirectoryPath: logsDirectory),
            performance: configuration.performancePreset,
            dateProvider: SystemDateProvider()
        )

        let dataFormat = DataFormat(prefix: "[", suffix: "]", separator: ",")

        let logsFileWriter = FileWriter(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator,
            queue: logsStorageQueue
        )

        let logsFileReader = FileReader(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator,
            queue: logsUploadQueue
        )

        logsStorage = FeatureStorage(writer: logsFileWriter, reader: logsFileReader)

        let requestBuilder = RequestBuilder(
            url: configuration.endpoint.logsURL,
            queryItems: [
                .ddsource(source: configuration.source)
            ],
            headers: [
                .contentTypeHeader(contentType: .applicationJSON),
                .userAgentHeader(
                    appName: configuration.applicationName,
                    appVersion: configuration.version,
                    device: Device.current
                ),
                .ddAPIKeyHeader(apiKey: configuration.apiKey),
                .ddEVPOriginHeader(source: configuration.source),
                .ddEVPOriginVersionHeader(version: configuration.version),
                .ddRequestIDHeader()
            ] + (configuration.payloadCompression ? [RequestBuilder.HTTPHeader.contentEncodingHeader(contentEncoding: .deflate)] : [])

        )

        logsUpload = FeatureUpload(featureName: "logsUpload",
                                   storage: logsStorage,
                                   requestBuilder: requestBuilder,
                                   performance: configuration.performancePreset,
                                   uploadCondition: configuration.uploadCondition)
    }

    func exportLogs(fromSpan span: SpanData) {
        span.events.forEach {
            let log = DDLog(event: $0, span: span, configuration: configuration)
            if configuration.performancePreset.synchronousWrite {
                logsStorage.writer.writeSync(value: log)
            } else {
                logsStorage.writer.write(value: log)
            }
        }
    }
}

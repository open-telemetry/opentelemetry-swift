/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

internal class SpansExporter {
    let tracesDirectory = "com.otel.datadog.traces/v1"
    let configuration: ExporterConfiguration
    let tracesStorage: FeatureStorage
    let tracesUpload: FeatureUpload

    init(config: ExporterConfiguration) throws {
        self.configuration = config

        let filesOrchestrator = FilesOrchestrator(
            directory: try Directory(withSubdirectoryPath: tracesDirectory),
            performance: configuration.performancePreset,
            dateProvider: SystemDateProvider()
        )

        let dataFormat = DataFormat(prefix: "", suffix: "", separator: "\n")

        let spanFileWriter = FileWriter(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator
        )

        let spanFileReader = FileReader(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator
        )

        tracesStorage = FeatureStorage(writer: spanFileWriter, reader: spanFileReader)

        let requestBuilder = RequestBuilder(
            url: configuration.endpoint.tracesURL,
            queryItems: [],
            headers: [
                .contentTypeHeader(contentType: .textPlainUTF8),
                .userAgentHeader(
                    appName: configuration.applicationName,
                    appVersion: configuration.version,
                    device: Device.current
                ),
                .ddAPIKeyHeader(apiKey: config.apiKey),
                .ddEVPOriginHeader(source: configuration.source),
                .ddEVPOriginVersionHeader(version: configuration.version),
                .ddRequestIDHeader(),
            ] + (configuration.payloadCompression ? [RequestBuilder.HTTPHeader.contentEncodingHeader(contentEncoding: .deflate)] : [])
        )

        tracesUpload = FeatureUpload(featureName: "tracesUpload",
                                     storage: tracesStorage,
                                     requestBuilder: requestBuilder,
                                     performance: configuration.performancePreset,
                                     uploadCondition: configuration.uploadCondition)
    }

    func exportSpan(span: SpanData) {
        let envelope = SpanEnvelope(span: DDSpan(spanData: span, configuration: configuration), environment: configuration.environment)
        if configuration.performancePreset.synchronousWrite {
            tracesStorage.writer.writeSync(value: envelope)
        } else {
            tracesStorage.writer.write(value: envelope)
        }
    }
}

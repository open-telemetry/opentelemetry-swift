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

internal class SpansExporter {
    let tracesDirectory = "com.otel.datadog.traces/v1"

    let configuration: ExporterConfiguration

    let tracesStorage: FeatureStorage
    let tracesStorageQueue = DispatchQueue(label: "com.otel.datadog.traceswriter", target: .global(qos: .userInteractive))

    let tracesUpload: FeatureUpload
    let tracesUploadQueue = DispatchQueue(label: "com.otel.datadog.tracesupload", target: .global(qos: .userInteractive))

    init(config: ExporterConfiguration) throws {
        guard let clientToken = config.clientToken else {
            throw ExporterError(description: "Span Exporter need a client token")
        }

        self.configuration = config

        let filesOrchestrator = FilesOrchestrator(
            directory: try Directory(withSubdirectoryPath: tracesDirectory),
            performance: configuration.performancePreset,
            dateProvider: SystemDateProvider()
        )

        let dataFormat = DataFormat(prefix: "", suffix: "", separator: "\n")

        let spanFileWriter = FileWriter(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator,
            queue: tracesStorageQueue
        )

        let spanFileReader = FileReader(
            dataFormat: dataFormat,
            orchestrator: filesOrchestrator,
            queue: tracesUploadQueue
        )

        tracesStorage = FeatureStorage(writer: spanFileWriter, reader: spanFileReader)

        let urlProvider = UploadURLProvider(
            urlWithClientToken: try configuration.endpoint.tracesUrlWithClientToken(clientToken: clientToken),
            queryItemProviders: [
                .batchTime(using: SystemDateProvider())
            ]
        )

        let httpHeaders = HTTPHeaders(headers: [
            .contentTypeHeader(contentType: .textPlainUTF8),
            .userAgentHeader(
                appName: configuration.applicationName,
                appVersion: configuration.version,
                device: Device.current
            )
        ])

        tracesUpload = FeatureUpload(featureName: "tracesUpload",
                                     storage: tracesStorage,
                                     uploadHTTPHeaders: httpHeaders,
                                     uploadURLProvider: urlProvider,
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

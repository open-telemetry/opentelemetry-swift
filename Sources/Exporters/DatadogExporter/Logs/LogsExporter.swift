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

        let dataFormat = DataFormat(prefix: "", suffix: "", separator: "\n")

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

        let urlProvider = UploadURLProvider(
            urlWithClientToken: try configuration.endpoint.logsUrlWithClientToken(clientToken: configuration.clientToken),
            queryItemProviders: [
                .batchTime(using: SystemDateProvider())
            ]
        )

        let httpHeaders = HTTPHeaders(headers: [
            .contentTypeHeader(contentType: .textPlainUTF8),
            .userAgentHeader(
                appName: configuration.applicationName,
                appVersion: configuration.applicationVersion,
                device: Device.current
            )
        ])

        logsUpload = FeatureUpload(featureName: "logsUpload",
                                   storage: logsStorage,
                                   uploadHTTPHeaders: httpHeaders,
                                   uploadURLProvider: urlProvider,
                                   performance: configuration.performancePreset,
                                   uploadCondition: configuration.uploadCondition)
    }

    func exportLogs(fromSpan span: SpanData) {
        span.timedEvents.forEach {
            let log = DDLog(timedEvent: $0, span: span, configuration: configuration)
            if configuration.performancePreset.synchronousWrite {
                logsStorage.writer.writeSync(value: log)
            } else {
                logsStorage.writer.write(value: log)
            }
        }
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import GRPC
import OpenTelemetryApi
import OpenTelemetrySdk

public class OtlpLogExporter : LogRecordExporter {
    let channel : GRPCChannel
    var logClient : Opentelemetry_Proto_Collector_Logs_V1_LogsServiceNIOClient
    let config : OtlpConfiguration
    var callOptions : CallOptions? = nil

    public init(channel: GRPCChannel,
                config: OtlpConfiguration = OtlpConfiguration(),
                logger: Logger = Logger(label: "io.grpc", factory: { _ in SwiftLogNoOpLogHandler() }),
                envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes){
        self.channel = channel
        logClient = Opentelemetry_Proto_Collector_Logs_V1_LogsServiceNIOClient(channel: channel)
        self.config = config
        if let headers = envVarHeaders {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
        } else if let headers = config.headers {
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
        }
        else {
            callOptions = CallOptions(logger: logger)
        }
    }

    public func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        let logRequest = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs
        }

        logClient.export(logRequest)
    }

    public func shutdown() {
    }

    public func forceFlush() -> ExportResult {
        fatalError("forceFlush() has not been implemented")
    }
}

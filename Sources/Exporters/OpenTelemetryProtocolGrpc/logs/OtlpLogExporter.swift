/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Logging
import GRPC
import NIO
import NIOHPACK
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

public class OtlpLogExporter : LogRecordExporter {
    let channel : GRPCChannel
    var logClient : Opentelemetry_Proto_Collector_Logs_V1_LogsServiceNIOClient
    let config : OtlpConfiguration
    var callOptions : CallOptions

    public init(channel: GRPCChannel,
                config: OtlpConfiguration = OtlpConfiguration(),
                logger: Logging.Logger = Logging.Logger(label: "io.grpc", factory: { _ in SwiftLogNoOpLogHandler() }),
                envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes){
        self.channel = channel
        logClient = Opentelemetry_Proto_Collector_Logs_V1_LogsServiceNIOClient(channel: channel)
        self.config = config
        let userAgentHeader = (Constants.HTTP.userAgent, Headers.getUserAgentHeader())
        if let headers = envVarHeaders {
            var updatedHeaders = headers
            updatedHeaders.append(userAgentHeader)
            callOptions = CallOptions(customMetadata: HPACKHeaders(updatedHeaders), logger: logger)
        } else if let headers = config.headers {
            var updatedHeaders = headers
            updatedHeaders.append(userAgentHeader)
            callOptions = CallOptions(customMetadata: HPACKHeaders(updatedHeaders), logger: logger)
        }
        else {
            var headers = [(String, String)]()
            headers.append(userAgentHeader)
            callOptions = CallOptions(customMetadata: HPACKHeaders(headers), logger: logger)
        }
    }

    public func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        let logRequest = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
        }
      
        if config.timeout > 0 {
          callOptions.timeLimit = TimeLimit.timeout(TimeAmount.nanoseconds(Int64(config.timeout.toNanoseconds)))
        }

      
        let export = logClient.export(logRequest, callOptions: callOptions)
        do {
            _ = try export.response.wait()
            return .success
        } catch {
            return .failure
        }
    }

    public func shutdown() {
        _ = channel.close()
    }

    public func forceFlush() -> ExportResult {
        .success
    }
}

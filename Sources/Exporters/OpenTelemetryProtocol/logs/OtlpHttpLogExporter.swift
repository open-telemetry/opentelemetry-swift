//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetrySdk

public func defaultOltpHttpLoggingEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/logs")!
}

public class OtlpHttpLogExporter : OtlpHttpExporterBase, LogRecordExporter {
    var pendingLogRecords: [ReadableLogRecord] = []
    
    override
    public init(endpoint: URL = defaultOltpHttpLoggingEndpoint(), useSession: URLSession? = nil) {
        super.init(endpoint: endpoint, useSession: useSession)
    }
    
    public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord]) -> OpenTelemetrySdk.ExportResult {
        pendingLogRecords.append(contentsOf: logRecords)
        return self.flush()
    }

    public func forceFlush() -> OpenTelemetrySdk.ExportResult {
        self.flush()
    }
    
    public func flush() -> ExportResult {
        var exporterResult: ExportResult = .failure
        let logRecords = pendingLogRecords
        pendingLogRecords = []
            
        let body = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
        }
        
        let request = createRequest(body: body, endpoint: endpoint)
        httpClient.send(request: request) { result in
            switch result {
            case .success(_):
                exporterResult = ExportResult.success
            case .failure(let error):
                print(error)
                exporterResult = ExportResult.failure
            }
        }
        return exporterResult
    }
}

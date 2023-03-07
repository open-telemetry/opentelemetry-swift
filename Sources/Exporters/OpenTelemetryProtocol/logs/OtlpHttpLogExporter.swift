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
        let sendingLogRecords = pendingLogRecords
        pendingLogRecords = []
        
        let body = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: sendingLogRecords)
        }
        
        let request = createRequest(body: body, endpoint: endpoint)
        httpClient.send(request: request) { [weak self] result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                self?.pendingLogRecords.append(contentsOf: sendingLogRecords)
                print(error)
            }
        }
        
        return .success
    }

    public func forceFlush() -> OpenTelemetrySdk.ExportResult {
        self.flush()
    }
    
    public func flush() -> ExportResult {
        var exporterResult: ExportResult = .success
        
        if !pendingLogRecords.isEmpty {
            let body = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
                request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: pendingLogRecords)
            }
            let semaphore = DispatchSemaphore(value: 0)
            let request = createRequest(body: body, endpoint: endpoint)
            
            httpClient.send(request: request) { result in
                switch result {
                case .success(_):
                    exporterResult = ExportResult.success
                case .failure(let error):
                    print(error)
                    exporterResult = ExportResult.failure
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
        
        return exporterResult
    }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import Logging
import NIO
import NIOHPACK
import OpenTelemetryApi
import OpenTelemetrySdk

public func defaultOltpHttpLoggingEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/logs")!
}

public class OtlpHttpLogExporter : LogRecordExporter {
    let endpoint: URL
    private let httpClient: HTTPClient
    var pendingLogRecords: [ReadableLogRecord] = []
    
    public init(endpoint: URL = defaultOltpHttpLoggingEndpoint(), useSession: URLSession? = nil) {
        self.endpoint = endpoint
        if let providedSession = useSession {
            self.httpClient = HTTPClient(session: providedSession)
        } else {
            self.httpClient = HTTPClient()
        }
    }
    
    public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord]) -> OpenTelemetrySdk.ExportResult {
        pendingLogRecords.append(contentsOf: logRecords)
        return self.flush()
    }
    
    public func shutdown() {
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

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try? body.serializedData()
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
            
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

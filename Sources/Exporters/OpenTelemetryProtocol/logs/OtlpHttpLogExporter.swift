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

public func defaultOltpHTTPLogsEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/metrics")!
}

public class OtlpHttpLogExporter : LogRecordExporter {
    let endpoint: URL
    let urlSession: URLSession
    let config : OtlpConfiguration

    public init(endpoint: URL = defaultOltpHTTPLogsEndpoint(), urlSession: URLSession = URLSession.shared, config: OtlpConfiguration = OtlpConfiguration()) {
        self.endpoint = endpoint
        self.urlSession = urlSession
        self.config = config
    }

    public func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        let logRequest = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try? logRequest.serializedData()
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        
        if let headers = config.headers {
            for header in headers {
                request.addValue(header.1, forHTTPHeaderField: header.0)
            }
        }

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error sending telemetry: \(error)")
            }
        }
        
        task.resume()
        
        return .success

    }
    
    public func shutdown() {
        
    }

    public func forceFlush() -> ExportResult {
        .success
    }
}

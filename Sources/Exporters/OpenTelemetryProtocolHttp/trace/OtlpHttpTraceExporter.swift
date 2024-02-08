//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

public func defaultOltpHttpTracesEndpoint() -> URL {
    URL(string: "http://localhost:4318/v1/traces")!
}

public class OtlpHttpTraceExporter: OtlpHttpExporterBase, SpanExporter {
    var pendingSpans: [SpanData] = []
    private let exporterLock = Lock()
    override
    public init(endpoint: URL = defaultOltpHttpTracesEndpoint(), config: OtlpConfiguration = OtlpConfiguration(),
                useSession: URLSession? = nil, envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
        super.init(endpoint: endpoint, config: config, useSession: useSession)
    }

    public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        var sendingSpans: [SpanData] = []
        exporterLock.withLockVoid {
            pendingSpans.append(contentsOf: spans)
            sendingSpans = pendingSpans
            pendingSpans = []
        }

        let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: sendingSpans)
        }
        var request = createRequest(body: body, endpoint: endpoint)
        if let headers = envVarHeaders {
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }

        } else if let headers = config.headers {
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        httpClient.send(request: request) { [weak self] result in
            switch result {
            case .success:
                break
            case let .failure(error):
                self?.exporterLock.withLockVoid {
                    self?.pendingSpans.append(contentsOf: sendingSpans)
                }
                print(error)
            }
        }
        return .success
    }

    public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        var resultValue: SpanExporterResultCode = .success
        var pendingSpans: [SpanData] = []
        exporterLock.withLockVoid {
            pendingSpans = self.pendingSpans
        }
        if !pendingSpans.isEmpty {
            let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
                $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: pendingSpans)
            }
            let semaphore = DispatchSemaphore(value: 0)
            let request = createRequest(body: body, endpoint: endpoint)

            httpClient.send(request: request) { result in
                switch result {
                case .success:
                    break
                case let .failure(error):
                    print(error)
                    resultValue = .failure
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
        return resultValue
    }
}

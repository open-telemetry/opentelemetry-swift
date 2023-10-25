//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

public func defaultOltpHttpLoggingEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/logs")!
}

public class OtlpHttpLogExporter : OtlpHttpExporterBase, LogRecordExporter {
  
  var pendingLogRecords: [ReadableLogRecord] = []
  let dispatchQueue = DispatchQueue(label: "OtlpHttpLogExporter Queue")

  override public init(endpoint: URL = defaultOltpHttpLoggingEndpoint(),
                       config: OtlpConfiguration = OtlpConfiguration(),
                       useSession: URLSession? = nil,
                       envVarHeaders: [(String,String)]? = EnvVarHeaders.attributes){
    super.init(endpoint: endpoint, config: config, useSession: useSession, envVarHeaders: envVarHeaders)
  }
  
  public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
  var sendingLogRecords: [ReadableLogRecord]!
    dispatchQueue.sync {
      pendingLogRecords.append(contentsOf: logRecords)
      sendingLogRecords = pendingLogRecords
      pendingLogRecords = []
    }

    let body = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
      request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: sendingLogRecords)
    }
    
    var request = createRequest(body: body, endpoint: endpoint)
    request.timeoutInterval = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude , config.timeout)
    httpClient.send(request: request) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(_):
        break
      case .failure(let error):
        self.dispatchQueue.sync { [weak self] in
          self?.pendingLogRecords.append(contentsOf: sendingLogRecords)
        }
        print(error)
      }
    }
    
    return .success
  }
  
  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    self.flush(explicitTimeout: explicitTimeout)
  }
  
  public func flush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    var exporterResult: ExportResult = .success
    var pendingLogRecords: [ReadableLogRecord]!
    dispatchQueue.sync {
      pendingLogRecords = self.pendingLogRecords
    }
    if !pendingLogRecords.isEmpty {
      let body = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
        request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: pendingLogRecords)
      }
      let semaphore = DispatchSemaphore(value: 0)
      var request = createRequest(body: body, endpoint: endpoint)
      request.timeoutInterval = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude , config.timeout)
      
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

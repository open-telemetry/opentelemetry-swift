//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public func defaultOltpHttpLoggingEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/logs")!
}

public final class OtlpHttpLogExporter: LogRecordExporter, @unchecked Sendable {
  private let base: OtlpHttpExporterBase<ReadableLogRecord>
  private var exporterMetrics: ExporterMetrics?

  init(base: OtlpHttpExporterBase<ReadableLogRecord>) {
    self.base = base
  }

  public convenience init(endpoint: URL = defaultOltpHttpLoggingEndpoint(),
                          config: OtlpConfiguration = OtlpConfiguration(),
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
                          requeueOnFailure: Bool = true) {
    self.init(base: OtlpHttpExporterBase(endpoint: endpoint,
                                         config: config,
                                         httpClient: httpClient,
                                         envVarHeaders: envVarHeaders,
                                         requeueOnFailure: requeueOnFailure))
  }

  /// A `convenience` constructor to provide support for exporter metric using`StableMeterProvider` type
  /// - Parameters:
  ///    - endpoint: Exporter endpoint injected as dependency
  ///    - config: Exporter configuration including type of exporter
  ///    - meterProvider: Injected `StableMeterProvider` for metric
  ///    - httpClient: Custom HTTPClient implementation
  ///    - envVarHeaders: Extra header key-values
  ///    - requeueOnFailure: Re-append failed batches to the in-memory pending queue
  public convenience init(endpoint: URL = defaultOltpHttpLoggingEndpoint(),
                          config: OtlpConfiguration = OtlpConfiguration(),
                          meterProvider: any MeterProvider,
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
                          requeueOnFailure: Bool = true) {
    self.init(endpoint: endpoint,
              config: config,
              httpClient: httpClient,
              envVarHeaders: envVarHeaders,
              requeueOnFailure: requeueOnFailure)
    exporterMetrics = ExporterMetrics(type: "log",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord],
                     explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
    let sendingLogRecords = base.drainPending(adding: logRecords)

    let body =
      Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
        request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(
          logRecordList: sendingLogRecords)
      }

    var request = base.createRequest(body: body, endpoint: base.endpoint)
    exporterMetrics?.addSeen(value: sendingLogRecords.count)
    request.timeoutInterval = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, base.config.timeout)
    base.httpClient.send(request: request) { [weak self] result in
      switch result {
      case .success:
        self?.exporterMetrics?.addSuccess(value: sendingLogRecords.count)
      case let .failure(error):
        self?.exporterMetrics?.addFailed(value: sendingLogRecords.count)
        self?.base.requeue(sendingLogRecords)
        OpenTelemetry.instance.feedbackHandler?("\(error)")
      }
    }

    return .success
  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    flush(explicitTimeout: explicitTimeout)
  }

  public func flush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    var exporterResult: ExportResult = .success
    let pendingLogRecords = base.snapshotPending()

    if !pendingLogRecords.isEmpty {
      let sentCount = pendingLogRecords.count
      let body =
        Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
          request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(
            logRecordList: pendingLogRecords)
        }
      let semaphore = DispatchSemaphore(value: 0)
      var request = base.createRequest(body: body, endpoint: base.endpoint)
      let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, base.config.timeout)
      request.timeoutInterval = timeout
      base.httpClient.send(request: request) { [weak self] result in
        switch result {
        case .success:
          self?.exporterMetrics?.addSuccess(value: sentCount)
          self?.base.dropFlushed(count: sentCount)
          exporterResult = ExportResult.success
        case let .failure(error):
          self?.exporterMetrics?.addFailed(value: sentCount)
          OpenTelemetry.instance.feedbackHandler?("\(error)")
          exporterResult = ExportResult.failure
        }
        semaphore.signal()
      }

      let waitResult = semaphore.wait(timeout: .now() + timeout)
      if waitResult == .timedOut {
        exporterMetrics?.addFailed(value: sentCount)
        return .failure
      }
    }

    return exporterResult
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {}
}

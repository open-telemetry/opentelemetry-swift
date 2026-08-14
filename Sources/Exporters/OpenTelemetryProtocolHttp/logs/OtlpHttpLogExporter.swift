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

public class OtlpHttpLogExporter: OtlpHttpExporterBase, LogRecordExporter, @unchecked Sendable {
  private let pendingQueue = PendingQueue<ReadableLogRecord>()
  var pendingLogRecords: [ReadableLogRecord] {
    pendingQueue.snapshot()
  }
  private var exporterMetrics: ExporterMetrics?

  override public init(endpoint: URL = defaultOltpHttpLoggingEndpoint(),
                       config: OtlpConfiguration = OtlpConfiguration(),
                       httpClient: HTTPClient = BaseHTTPClient(),
                       envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    super.init(endpoint: endpoint,
               config: config,
               httpClient: httpClient,
               envVarHeaders: envVarHeaders)
  }

  /// A `convenience` constructor to provide support for exporter metric using`StableMeterProvider` type
  /// - Parameters:
  ///    - endpoint: Exporter endpoint injected as dependency
  ///    - config: Exporter configuration including type of exporter
  ///    - meterProvider: Injected `StableMeterProvider` for metric
  ///    - httpClient: Custom HTTPClient implementation
  ///    - envVarHeaders: Extra header key-values
  public convenience init(endpoint: URL = defaultOltpHttpLoggingEndpoint(),
                          config: OtlpConfiguration = OtlpConfiguration(),
                          meterProvider: any MeterProvider,
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(endpoint: endpoint, config: config, httpClient: httpClient,
              envVarHeaders: envVarHeaders)
    exporterMetrics = ExporterMetrics(type: "log",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord],
                     explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
    let estimatedCount = logRecords.count + pendingQueue.snapshot().count
    return waitSynchronously(timeout: timeout) {
      await self.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    } ?? {
      exporterMetrics?.addFailed(value: estimatedCount)
      return .failure
    }()
  }

  public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord],
                     explicitTimeout: TimeInterval? = nil) async -> OpenTelemetrySdk.ExportResult {
    let batch = pendingQueue.enqueueAndTakeAll(logRecords)
    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
    return await sendBatch(batch, timeout: timeout, isFlush: false)
  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    flush(explicitTimeout: explicitTimeout)
  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) async -> ExportResult {
    await flush(explicitTimeout: explicitTimeout)
  }

  public func flush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
    let pendingCount = pendingQueue.snapshot().count
    return waitSynchronously(timeout: timeout) {
      await self.flush(explicitTimeout: explicitTimeout)
    } ?? {
      exporterMetrics?.addFailed(value: pendingCount)
      return .failure
    }()
  }

  public func flush(explicitTimeout: TimeInterval? = nil) async -> ExportResult {
    let pending = pendingQueue.snapshot()
    guard !pending.isEmpty else { return .success }
    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
    let result = await sendBatch(pending, timeout: timeout, isFlush: true)
    if case .success = result {
      pendingQueue.dropPrefix(pending.count)
    }
    return result
  }

  public func shutdown(explicitTimeout: TimeInterval?) async {}

  private func sendBatch(_ batch: [ReadableLogRecord],
                         timeout: TimeInterval,
                         isFlush: Bool) async -> ExportResult {
    let body =
      Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
        request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(
          logRecordList: batch)
      }

    var request = createRequest(body: body, endpoint: endpoint)
    request.timeoutInterval = timeout
    if isFlush {
      if let headers = envVarHeaders {
        headers.forEach { key, value in
          request.addValue(value, forHTTPHeaderField: key)
        }
      } else if let headers = config.headers {
        headers.forEach { key, value in
          request.addValue(value, forHTTPHeaderField: key)
        }
      }
    }
    if !isFlush {
      exporterMetrics?.addSeen(value: batch.count)
    }

    let sendResult = await sendWithTimeout(httpClient: httpClient, timeout: timeout, request: request)
    switch sendResult {
    case .success:
      exporterMetrics?.addSuccess(value: batch.count)
      return .success
    case let .failure(error):
      exporterMetrics?.addFailed(value: batch.count)
      if !isFlush, !(error is OtlpHttpExportTimeoutError) {
        pendingQueue.requeue(batch)
      }
      if !(error is OtlpHttpExportTimeoutError) {
        OpenTelemetry.instance.feedbackHandler?("\(error)")
      }
      return .failure
    }
  }
}

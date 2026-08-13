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

public func defaultOltpHttpTracesEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/traces")!
}

public class OtlpHttpTraceExporter: OtlpHttpExporterBase, SpanExporter, @unchecked Sendable {
  private let pendingQueue = PendingQueue<SpanData>()
  var pendingSpans: [SpanData] {
    pendingQueue.snapshot()
  }

  private var exporterMetrics: ExporterMetrics?

  override public init(endpoint: URL = defaultOltpHttpTracesEndpoint(),
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
  public convenience init(endpoint: URL,
                          config: OtlpConfiguration,
                          meterProvider: any MeterProvider,
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(endpoint: endpoint, config: config, httpClient: httpClient,
              envVarHeaders: envVarHeaders)
    exporterMetrics = ExporterMetrics(type: "span",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil)
    -> SpanExporterResultCode {
    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
    let estimatedCount = spans.count + pendingQueue.snapshot().count
    return waitSynchronously(timeout: timeout) {
      await self.export(spans: spans, explicitTimeout: explicitTimeout)
    } ?? {
      exporterMetrics?.addFailed(value: estimatedCount)
      return .failure
    }()
  }

  @discardableResult
  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) async
    -> SpanExporterResultCode {
    let batch = pendingQueue.enqueueAndTakeAll(spans)
    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
    return await sendBatch(batch, timeout: timeout, isFlush: false)
  }

  public func flush(explicitTimeout: TimeInterval? = nil)
    -> SpanExporterResultCode {
    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
    let pendingCount = pendingQueue.snapshot().count
    return waitSynchronously(timeout: timeout) {
      await self.flush(explicitTimeout: explicitTimeout)
    } ?? {
      exporterMetrics?.addFailed(value: pendingCount)
      return .failure
    }()
  }

  public func flush(explicitTimeout: TimeInterval? = nil) async -> SpanExporterResultCode {
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

  private func sendBatch(_ batch: [SpanData],
                         timeout: TimeInterval,
                         isFlush: Bool) async -> SpanExporterResultCode {
    let body =
      Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
        $0.resourceSpans = SpanAdapter.toProtoResourceSpans(
          spanDataList: batch)
      }
    var request = createRequest(body: body, endpoint: endpoint)
    request.timeoutInterval = timeout
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

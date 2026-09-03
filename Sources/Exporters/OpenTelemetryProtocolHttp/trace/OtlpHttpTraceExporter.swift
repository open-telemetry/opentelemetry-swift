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

public final class OtlpHttpTraceExporter: SpanExporter, @unchecked Sendable {
  private let base: OtlpHttpExporterBase<SpanData>
  private var exporterMetrics: ExporterMetrics?

  init(base: OtlpHttpExporterBase<SpanData>) {
    self.base = base
  }

  public convenience init(endpoint: URL = defaultOltpHttpTracesEndpoint(),
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
  public convenience init(endpoint: URL,
                          config: OtlpConfiguration,
                          meterProvider: any MeterProvider,
                          httpClient: HTTPClient = BaseHTTPClient(),
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
                          requeueOnFailure: Bool = true) {
    self.init(endpoint: endpoint,
              config: config,
              httpClient: httpClient,
              envVarHeaders: envVarHeaders,
              requeueOnFailure: requeueOnFailure)
    exporterMetrics = ExporterMetrics(type: "span",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil)
    -> SpanExporterResultCode {
    var resultValue: SpanExporterResultCode = .success
    let sendingSpans = base.drainPending(adding: spans)

    let body =
      Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
        $0.resourceSpans = SpanAdapter.toProtoResourceSpans(
          spanDataList: sendingSpans)
      }
    let semaphore = DispatchSemaphore(value: 0)
    var request = base.createRequest(body: body, endpoint: base.endpoint)

    let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, base.config.timeout)
    request.timeoutInterval = timeout

    exporterMetrics?.addSeen(value: sendingSpans.count)
    base.httpClient.send(request: request) { [weak self] result in
      switch result {
      case .success:
        self?.exporterMetrics?.addSuccess(value: sendingSpans.count)
      case let .failure(error):
        self?.exporterMetrics?.addFailed(value: sendingSpans.count)
        self?.base.requeue(sendingSpans)
        OpenTelemetry.instance.feedbackHandler?("\(error)")
        resultValue = .failure
      }
      semaphore.signal()
    }

    let waitResult = semaphore.wait(timeout: .now() + timeout)
    if waitResult == .timedOut {
      exporterMetrics?.addFailed(value: sendingSpans.count)
      return .failure
    }
    return resultValue
  }

  public func flush(explicitTimeout: TimeInterval? = nil)
    -> SpanExporterResultCode {
    var resultValue: SpanExporterResultCode = .success
    let pendingSpans = base.snapshotPending()
    if !pendingSpans.isEmpty {
      let sentCount = pendingSpans.count
      let body =
        Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
          $0.resourceSpans = SpanAdapter.toProtoResourceSpans(
            spanDataList: pendingSpans)
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
        case let .failure(error):
          self?.exporterMetrics?.addFailed(value: sentCount)
          OpenTelemetry.instance.feedbackHandler?("\(error)")
          resultValue = .failure
        }
        semaphore.signal()
      }

      let waitResult = semaphore.wait(timeout: .now() + timeout)
      if waitResult == .timedOut {
        exporterMetrics?.addFailed(value: sentCount)
        return .failure
      }
    }
    return resultValue
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {}
}

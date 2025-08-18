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

public class OtlpHttpTraceExporter: OtlpHttpExporterBase, SpanExporter {
  var pendingSpans: [SpanData] = []

  private let exporterLock = Lock()
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
    var sendingSpans: [SpanData] = []
    exporterLock.withLockVoid {
      pendingSpans.append(contentsOf: spans)
      sendingSpans = pendingSpans
      pendingSpans = []
    }

    let body =
      Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
        $0.resourceSpans = SpanAdapter.toProtoResourceSpans(
          spanDataList: sendingSpans)
      }
    let request = createRequest(body: body, endpoint: endpoint)
    exporterMetrics?.addSeen(value: sendingSpans.count)
    httpClient.send(request: request) { [weak self] result in
      switch result {
      case .success:
        self?.exporterMetrics?.addSuccess(value: sendingSpans.count)
      case let .failure(error):
        self?.exporterMetrics?.addFailed(value: sendingSpans.count)
        self?.exporterLock.withLockVoid {
          self?.pendingSpans.append(contentsOf: sendingSpans)
        }
        print(error)
      }
    }
    return .success
  }

  public func flush(explicitTimeout: TimeInterval? = nil)
    -> SpanExporterResultCode {
    var resultValue: SpanExporterResultCode = .success
    var pendingSpans: [SpanData] = []
    exporterLock.withLockVoid {
      pendingSpans = self.pendingSpans
    }
    if !pendingSpans.isEmpty {
      let body =
        Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
          $0.resourceSpans = SpanAdapter.toProtoResourceSpans(
            spanDataList: pendingSpans)
        }
      let semaphore = DispatchSemaphore(value: 0)
      let request = createRequest(body: body, endpoint: endpoint)

      httpClient.send(request: request) { [weak self] result in
        switch result {
        case .success:
          self?.exporterMetrics?.addSuccess(value: pendingSpans.count)
        case let .failure(error):
          self?.exporterMetrics?.addFailed(value: pendingSpans.count)
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
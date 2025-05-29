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

public func defaultOltpHTTPMetricsEndpoint() -> URL {
  URL(string: "http://localhost:4318/v1/metrics")!
}

@available(*, deprecated, renamed: "StableOtlpHTTPMetricExporter")
public class OtlpHttpMetricExporter: OtlpHttpExporterBase, MetricExporter {
  var pendingMetrics: [Metric] = []
  private let exporterLock = Lock()
  private var exporterMetrics: ExporterMetrics?

  override
  public init(endpoint: URL = defaultOltpHTTPMetricsEndpoint(),
              config: OtlpConfiguration = OtlpConfiguration(),
              useSession: URLSession? = nil,
              envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    super.init(endpoint: endpoint,
               config: config,
               useSession: useSession,
               envVarHeaders: envVarHeaders)
  }

  /// A `convenience` constructor to provide support for exporter metric using`StableMeterProvider` type
  /// - Parameters:
  ///    - endpoint: Exporter endpoint injected as dependency
  ///    - config: Exporter configuration including type of exporter
  ///    - meterProvider: Injected `StableMeterProvider` for metric
  ///    - useSession: Overridden `URLSession` if any
  ///    - envVarHeaders: Extra header key-values
  public convenience init(endpoint: URL = defaultOltpHTTPMetricsEndpoint(),
                          config: OtlpConfiguration = OtlpConfiguration(),
                          meterProvider: any StableMeterProvider,
                          useSession: URLSession? = nil,
                          envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
    self.init(endpoint: endpoint, config: config, useSession: useSession,
              envVarHeaders: envVarHeaders)
    exporterMetrics = ExporterMetrics(type: "metric",
                                      meterProvider: meterProvider,
                                      exporterName: "otlp",
                                      transportName: config.exportAsJson
                                        ? ExporterMetrics.TransporterType.httpJson
                                        : ExporterMetrics.TransporterType.grpc)
  }

  public func export(metrics: [Metric], shouldCancel: (() -> Bool)?)
    -> MetricExporterResultCode {
    var sendingMetrics: [Metric] = []
    exporterLock.withLockVoid {
      pendingMetrics.append(contentsOf: metrics)
      sendingMetrics = pendingMetrics
      pendingMetrics = []
    }
    let body =
      Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
        $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
          metricDataList: sendingMetrics)
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
    exporterMetrics?.addSeen(value: sendingMetrics.count)
    httpClient.send(request: request) { [weak self] result in
      switch result {
      case .success:
        self?.exporterMetrics?.addSuccess(value: sendingMetrics.count)
      case let .failure(error):
        self?.exporterMetrics?.addFailed(value: sendingMetrics.count)
        self?.exporterLock.withLockVoid {
          self?.pendingMetrics.append(contentsOf: sendingMetrics)
        }
        print(error)
      }
    }

    return .success
  }

  public func flush() -> MetricExporterResultCode {
    var exporterResult: MetricExporterResultCode = .success

    if !pendingMetrics.isEmpty {
      let body =
        Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest
          .with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
              metricDataList: pendingMetrics)
          }

      let semaphore = DispatchSemaphore(value: 0)
      let request = createRequest(body: body, endpoint: endpoint)
      httpClient.send(request: request) { [weak self, count = pendingMetrics.count] result in
        switch result {
        case .success:
          self?.exporterMetrics?.addSuccess(value: count)
        case let .failure(error):
          self?.exporterMetrics?.addFailed(value: count)
          print(error)
          exporterResult = MetricExporterResultCode.failureNotRetryable
        }
        semaphore.signal()
      }
      semaphore.wait()
    }
    return exporterResult
  }
}

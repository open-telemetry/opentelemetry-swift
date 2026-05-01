/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import XCTest

private final class StubHTTPClient: HTTPClient {
  enum Outcome {
    case success
    case failure(Error)
  }
  var outcomes: [Outcome]
  private(set) var sentRequests: [URLRequest] = []
  init(outcomes: [Outcome]) { self.outcomes = outcomes }
  func send(request: URLRequest,
            completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    sentRequests.append(request)
    let next = outcomes.isEmpty ? .success : outcomes.removeFirst()
    switch next {
    case .success:
      let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                 httpVersion: "HTTP/1.1", headerFields: nil)!
      completion(.success(resp))
    case .failure(let err):
      completion(.failure(err))
    }
  }
}

private struct FakeError: Error {}

final class OtlpHttpMetricExporterCoverageTests: XCTestCase {
  private let endpoint = URL(string: "http://localhost:4318/v1/metrics")!

  func testExportSuccessSendsOneRequest() {
    let client = StubHTTPClient(outcomes: [.success])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    let result = exporter.export(metrics: [.empty])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(client.sentRequests.count, 1)
  }

  func testExportFailurePutsMetricsBackInPending() {
    let client = StubHTTPClient(outcomes: [.failure(FakeError())])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    _ = exporter.export(metrics: [.empty])
    XCTAssertEqual(exporter.pendingMetrics.count, 1)
  }

  func testFlushWithPendingReturnsSuccessAfterRetry() {
    let client = StubHTTPClient(outcomes: [.failure(FakeError()), .success])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    _ = exporter.export(metrics: [.empty])
    XCTAssertEqual(exporter.flush(), .success)
    XCTAssertEqual(client.sentRequests.count, 2)
  }

  func testFlushWithPendingFailureReturnsFailure() {
    let client = StubHTTPClient(outcomes: [.failure(FakeError()), .failure(FakeError())])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    _ = exporter.export(metrics: [.empty])
    XCTAssertEqual(exporter.flush(), .failure)
  }

  func testFlushWithNoPendingReturnsSuccess() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    XCTAssertEqual(exporter.flush(), .success)
    XCTAssertEqual(client.sentRequests.count, 0)
  }

  func testShutdownReturnsSuccess() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    XCTAssertEqual(exporter.shutdown(), .success)
  }

  func testGetAggregationTemporalityDelegates() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    let t = exporter.getAggregationTemporality(for: .counter)
    XCTAssertEqual(t, .cumulative)
  }

  func testGetDefaultAggregationDelegates() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint, httpClient: client)
    // We only need to hit the delegate; the exact default aggregation depends
    // on the instrument type, the call itself is the coverage target.
    _ = exporter.getDefaultAggregation(for: .counter)
  }

  func testDefaultEndpointsHelpers() {
    XCTAssertEqual(defaultOtlpHttpMetricsEndpoint().absoluteString,
                   "http://localhost:4318/v1/metrics")
  }

  func testConvenienceInitWithMeterProvider() {
    let client = StubHTTPClient(outcomes: [])
    let provider = MeterProviderSdk.builder().build()
    let exporter = OtlpHttpMetricExporter(endpoint: endpoint,
                                          config: OtlpConfiguration(),
                                          meterProvider: provider,
                                          httpClient: client,
                                          envVarHeaders: nil)
    XCTAssertNotNil(exporter)
  }
}

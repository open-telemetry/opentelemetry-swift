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

/// Minimal HTTPClient stub that the HTTP exporters delegate to, so we can drive
/// them through success/failure paths without needing a live server. Keeps test
/// semantics deterministic and exercises the exporter's fallback / metric
/// branches.
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
      let resp = HTTPURLResponse(url: request.url!,
                                 statusCode: 200,
                                 httpVersion: "HTTP/1.1",
                                 headerFields: nil)!
      completion(.success(resp))
    case .failure(let err):
      completion(.failure(err))
    }
  }
}

private struct TransientNetworkError: Error {}

private func sampleLogRecord() -> ReadableLogRecord {
  let ctx = SpanContext.create(traceId: TraceId.random(),
                               spanId: SpanId.random(),
                               traceFlags: TraceFlags(),
                               traceState: TraceState())
  return ReadableLogRecord(resource: Resource(),
                           instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                           timestamp: Date(),
                           observedTimestamp: Date(),
                           spanContext: ctx,
                           severity: .info,
                           body: .string("hello"),
                           attributes: [:])
}

private func sampleSpanData() -> SpanData {
  SpanData(traceId: TraceId.random(),
           spanId: SpanId.random(),
           traceFlags: TraceFlags(),
           traceState: TraceState(),
           resource: Resource(),
           instrumentationScope: InstrumentationScopeInfo(),
           name: "span",
           kind: .internal,
           startTime: Date(),
           endTime: Date(),
           hasRemoteParent: false)
}

final class OtlpHttpLogExporterCoverageTests: XCTestCase {
  func testExportFailurePutsRecordsBackInPending() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpLogExporter(httpClient: client)

    let rec = sampleLogRecord()
    let result = exporter.export(logRecords: [rec])
    XCTAssertEqual(result, .success)

    // Failure path should put the record back into pendingLogRecords.
    XCTAssertEqual(exporter.pendingLogRecords.count, 1)
    XCTAssertEqual(client.sentRequests.count, 1)
  }

  func testFlushWithPendingLogRecordsSuccess() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError()), .success])
    let exporter = OtlpHttpLogExporter(httpClient: client)

    _ = exporter.export(logRecords: [sampleLogRecord()])
    XCTAssertEqual(exporter.pendingLogRecords.count, 1)

    let flushResult = exporter.flush()
    XCTAssertEqual(flushResult, .success)
    XCTAssertEqual(client.sentRequests.count, 2)
  }

  func testFlushWithNoPendingReturnsSuccess() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpLogExporter(httpClient: client)
    XCTAssertEqual(exporter.flush(), .success)
    XCTAssertEqual(client.sentRequests.count, 0)
  }

  func testForceFlushDelegatesToFlush() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpLogExporter(httpClient: client)
    XCTAssertEqual(exporter.forceFlush(), .success)
  }

  func testFlushWithEnvVarHeadersAppliesHeaders() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError()), .success])
    let exporter = OtlpHttpLogExporter(
      httpClient: client,
      envVarHeaders: [("X-Test", "value")])
    _ = exporter.export(logRecords: [sampleLogRecord()])
    _ = exporter.flush()
    // Header may be appended twice (export + flush); accept either "value" or
    // the comma-joined duplicate form that URLRequest produces on addValue.
    let header = client.sentRequests.last?.value(forHTTPHeaderField: "X-Test") ?? ""
    XCTAssertTrue(header.contains("value"))
  }

  func testFlushWithConfigHeadersAppliesHeaders() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError()), .success])
    let config = OtlpConfiguration(headers: [("X-Config", "c-value")])
    let exporter = OtlpHttpLogExporter(config: config, httpClient: client, envVarHeaders: nil)
    _ = exporter.export(logRecords: [sampleLogRecord()])
    _ = exporter.flush()
    let header = client.sentRequests.last?.value(forHTTPHeaderField: "X-Config") ?? ""
    XCTAssertTrue(header.contains("c-value"))
  }

  func testFlushFailureAfterRetryReturnsFailure() {
    // export fails → record goes back to pending. flush also fails → exporter
    // reports .failure and exercises the failure branch inside flush().
    let client = StubHTTPClient(outcomes: [
      .failure(TransientNetworkError()),
      .failure(TransientNetworkError())
    ])
    let exporter = OtlpHttpLogExporter(httpClient: client)
    _ = exporter.export(logRecords: [sampleLogRecord()])
    XCTAssertEqual(exporter.flush(), .failure)
  }
}

final class OtlpHttpTraceExporterCoverageTests: XCTestCase {
  func testExportSuccessSendsRequest() {
    let client = StubHTTPClient(outcomes: [.success])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    let result = exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(client.sentRequests.count, 1)
  }

  func testExportFailureReturnsFailure() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    let result = exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(result, .failure)
  }

  func testFlushWithPendingSpans() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError()), .success])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    _ = exporter.export(spans: [sampleSpanData()])  // failure → back to pending
    XCTAssertEqual(exporter.flush(), .success)
    XCTAssertEqual(client.sentRequests.count, 2)
  }

  func testFlushWithNoPendingReturnsSuccess() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    XCTAssertEqual(exporter.flush(), .success)
  }

  func testShutdownReturnsWithoutError() {
    let client = StubHTTPClient(outcomes: [])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    exporter.shutdown()
  }

  func testFlushFailureAfterRetryReturnsFailure() {
    // export fails, then flush also fails — exercises the .failure branch
    // inside flush() and increments the failure metric counter.
    let client = StubHTTPClient(outcomes: [
      .failure(TransientNetworkError()),
      .failure(TransientNetworkError())
    ])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    _ = exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(exporter.flush(), .failure)
  }

  func testFlushFailureWithMeterProviderRecordsFailedCounter() {
    // The failure branch in flush() calls `addFailed` on ExporterMetrics when a
    // meter provider was wired in, exercising a different statement.
    let client = StubHTTPClient(outcomes: [
      .failure(TransientNetworkError()),
      .failure(TransientNetworkError())
    ])
    let provider = MeterProviderSdk.builder().build()
    let exporter = OtlpHttpTraceExporter(endpoint: URL(string: "http://x")!,
                                          config: OtlpConfiguration(),
                                          meterProvider: provider,
                                          httpClient: client,
                                          envVarHeaders: nil)
    _ = exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(exporter.flush(), .failure)
  }

  func testDefaultEndpointHelper() {
    XCTAssertEqual(defaultOltpHttpTracesEndpoint().absoluteString,
                   "http://localhost:4318/v1/traces")
  }

  func testConvenienceInitWithMeterProvider() {
    let client = StubHTTPClient(outcomes: [])
    let provider = MeterProviderSdk.builder().build()
    let exporter = OtlpHttpTraceExporter(endpoint: URL(string: "http://x")!,
                                          config: OtlpConfiguration(),
                                          meterProvider: provider,
                                          httpClient: client,
                                          envVarHeaders: nil)
    XCTAssertNotNil(exporter)
  }
}

final class OtlpHttpLogExporterDefaultEndpointTests: XCTestCase {
  func testDefaultEndpointHelper() {
    XCTAssertEqual(defaultOltpHttpLoggingEndpoint().absoluteString,
                   "http://localhost:4318/v1/logs")
  }

  func testConvenienceInitWithMeterProvider() {
    let provider = MeterProviderSdk.builder().build()
    let exporter = OtlpHttpLogExporter(endpoint: URL(string: "http://x")!,
                                        config: OtlpConfiguration(),
                                        meterProvider: provider,
                                        httpClient: BaseHTTPClient(),
                                        envVarHeaders: nil)
    XCTAssertNotNil(exporter)
  }
}

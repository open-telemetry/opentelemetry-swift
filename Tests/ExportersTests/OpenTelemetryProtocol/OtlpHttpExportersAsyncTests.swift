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
  private let lock = NSLock()

  init(outcomes: [Outcome]) { self.outcomes = outcomes }

  func send(request: URLRequest,
            completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    let next = lock.withLock {
      sentRequests.append(request)
      return outcomes.isEmpty ? .success : outcomes.removeFirst()
    }
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

  func send(request: URLRequest) async throws -> HTTPURLResponse {
    let next = lock.withLock {
      sentRequests.append(request)
      return outcomes.isEmpty ? .success : outcomes.removeFirst()
    }
    switch next {
    case .success:
      return HTTPURLResponse(url: request.url!,
                             statusCode: 200,
                             httpVersion: "HTTP/1.1",
                             headerFields: nil)!
    case .failure(let err):
      throw err
    }
  }
}

private struct TransientNetworkError: Error {}

private final class HangingHTTPClient: HTTPClient {
  private(set) var sendCount = 0
  private let lock = NSLock()

  func send(request: URLRequest,
            completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    lock.withLock { sendCount += 1 }
  }

  func send(request: URLRequest) async throws -> HTTPURLResponse {
    lock.withLock { sendCount += 1 }
    return await withCheckedContinuation { (_: CheckedContinuation<HTTPURLResponse, Never>) in }
  }
}

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

final class OtlpHttpExportersAsyncTests: XCTestCase {
  private let timeout: TimeInterval = 0.5
  private let metricsEndpoint = URL(string: "http://localhost:4318/v1/metrics")!

  func testLogAsyncExportSuccess() async {
    let client = StubHTTPClient(outcomes: [.success])
    let exporter = OtlpHttpLogExporter(httpClient: client)
    let result = await exporter.export(logRecords: [sampleLogRecord()])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(client.sentRequests.count, 1)
  }

  func testLogAsyncExportFailureRequeuesPending() async {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpLogExporter(httpClient: client)
    let result = await exporter.export(logRecords: [sampleLogRecord()])
    XCTAssertEqual(result, .failure)
    XCTAssertEqual(exporter.pendingLogRecords.count, 1)
  }

  func testLogAsyncExportTimesOut() async {
    let client = HangingHTTPClient()
    let exporter = OtlpHttpLogExporter(config: OtlpConfiguration(timeout: timeout),
                                       httpClient: client)
    let start = Date()
    let result = await exporter.export(logRecords: [sampleLogRecord()])
    XCTAssertEqual(result, .failure)
    XCTAssertLessThan(Date().timeIntervalSince(start), timeout * 4)
  }

  func testLogAsyncFlushDropsPendingAfterRetry() async {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError()), .success])
    let exporter = OtlpHttpLogExporter(httpClient: client)
    _ = await exporter.export(logRecords: [sampleLogRecord()])
    XCTAssertEqual(exporter.pendingLogRecords.count, 1)
    let flushResult = await exporter.flush()
    XCTAssertEqual(flushResult, .success)
    XCTAssertEqual(exporter.pendingLogRecords.count, 0)
    XCTAssertEqual(client.sentRequests.count, 2)
  }

  func testLogConcurrentAsyncExport() async {
    let client = StubHTTPClient(outcomes: Array(repeating: .success, count: 10))
    let exporter = OtlpHttpLogExporter(httpClient: client)
    await withTaskGroup(of: ExportResult.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await exporter.export(logRecords: [sampleLogRecord()])
        }
      }
      for await result in group {
        XCTAssertEqual(result, .success)
      }
    }
    XCTAssertEqual(client.sentRequests.count, 10)
  }

  func testLogSyncExportFailureWithFailingStub() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpLogExporter(httpClient: client)
    XCTAssertEqual(exporter.export(logRecords: [sampleLogRecord()]), .failure)
  }

  func testMetricAsyncExportSuccess() async {
    let client = StubHTTPClient(outcomes: [.success])
    let exporter = OtlpHttpMetricExporter(endpoint: metricsEndpoint, httpClient: client)
    let result = await exporter.export(metrics: [.empty])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(client.sentRequests.count, 1)
  }

  func testMetricAsyncExportFailureRequeuesPending() async {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpMetricExporter(endpoint: metricsEndpoint, httpClient: client)
    let result = await exporter.export(metrics: [.empty])
    XCTAssertEqual(result, .failure)
    XCTAssertEqual(exporter.pendingMetrics.count, 1)
  }

  func testMetricAsyncExportTimesOut() async {
    let client = HangingHTTPClient()
    let exporter = OtlpHttpMetricExporter(endpoint: metricsEndpoint,
                                          config: OtlpConfiguration(timeout: timeout),
                                          httpClient: client)
    let start = Date()
    let result = await exporter.export(metrics: [.empty])
    XCTAssertEqual(result, .failure)
    XCTAssertLessThan(Date().timeIntervalSince(start), timeout * 4)
  }

  func testMetricAsyncFlushDropsPendingAfterRetry() async {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError()), .success])
    let exporter = OtlpHttpMetricExporter(endpoint: metricsEndpoint, httpClient: client)
    _ = await exporter.export(metrics: [.empty])
    XCTAssertEqual(exporter.pendingMetrics.count, 1)
    let flushResult = await exporter.flush()
    XCTAssertEqual(flushResult, .success)
    XCTAssertEqual(exporter.pendingMetrics.count, 0)
    XCTAssertEqual(client.sentRequests.count, 2)
  }

  func testMetricConcurrentAsyncExport() async {
    let client = StubHTTPClient(outcomes: Array(repeating: .success, count: 10))
    let exporter = OtlpHttpMetricExporter(endpoint: metricsEndpoint, httpClient: client)
    await withTaskGroup(of: ExportResult.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await exporter.export(metrics: [.empty])
        }
      }
      for await result in group {
        XCTAssertEqual(result, .success)
      }
    }
    XCTAssertEqual(client.sentRequests.count, 10)
  }

  func testMetricSyncExportFailureWithFailingStub() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpMetricExporter(endpoint: metricsEndpoint, httpClient: client)
    XCTAssertEqual(exporter.export(metrics: [.empty]), .failure)
  }

  func testTraceAsyncExportSuccess() async {
    let client = StubHTTPClient(outcomes: [.success])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    let result = await exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(result, .success)
    XCTAssertEqual(client.sentRequests.count, 1)
  }

  func testTraceAsyncExportFailureRequeuesPending() async {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    let result = await exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(result, .failure)
    XCTAssertEqual(exporter.pendingSpans.count, 1)
  }

  func testTraceAsyncExportTimesOut() async {
    let client = HangingHTTPClient()
    let exporter = OtlpHttpTraceExporter(config: OtlpConfiguration(timeout: timeout),
                                         httpClient: client)
    let start = Date()
    let result = await exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(result, .failure)
    XCTAssertLessThan(Date().timeIntervalSince(start), timeout * 4)
  }

  func testTraceAsyncFlushDropsPendingAfterRetry() async {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError()), .success])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    _ = await exporter.export(spans: [sampleSpanData()])
    XCTAssertEqual(exporter.pendingSpans.count, 1)
    let flushResult = await exporter.flush()
    XCTAssertEqual(flushResult, .success)
    XCTAssertEqual(exporter.pendingSpans.count, 0)
    XCTAssertEqual(client.sentRequests.count, 2)
  }

  func testTraceConcurrentAsyncExport() async {
    let client = StubHTTPClient(outcomes: Array(repeating: .success, count: 10))
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    await withTaskGroup(of: SpanExporterResultCode.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await exporter.export(spans: [sampleSpanData()])
        }
      }
      for await result in group {
        XCTAssertEqual(result, .success)
      }
    }
    XCTAssertEqual(client.sentRequests.count, 10)
  }

  func testTraceSyncExportFailureWithFailingStub() {
    let client = StubHTTPClient(outcomes: [.failure(TransientNetworkError())])
    let exporter = OtlpHttpTraceExporter(httpClient: client)
    XCTAssertEqual(exporter.export(spans: [sampleSpanData()]), .failure)
  }
}

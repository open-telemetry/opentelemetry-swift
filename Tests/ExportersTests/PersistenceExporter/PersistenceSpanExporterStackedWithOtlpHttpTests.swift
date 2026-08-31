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
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
@testable import PersistenceExporter
import SwiftProtobuf
import XCTest

/// When Persistence wraps an OTLP HTTP trace exporter, both layers used to retry
/// the same failed batch. With `requeueOnFailure: false`, the exporter leaves its
/// pending queue empty so Persistence can retry from disk without duplicating spans.
final class PersistenceSpanExporterStackedWithOtlpHttpTests: XCTestCase {
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  private final class FailOnceHTTPClient: HTTPClient, @unchecked Sendable {
    struct SendFailure: Error {}

    private let lock = NSLock()
    private var _sentBodies: [Data] = []
    private let firstRequestSent: XCTestExpectation
    private let secondRequestSent: XCTestExpectation

    var sentBodies: [Data] {
      lock.lock()
      defer { lock.unlock() }
      return _sentBodies
    }

    init(firstRequestSent: XCTestExpectation, secondRequestSent: XCTestExpectation) {
      self.firstRequestSent = firstRequestSent
      self.secondRequestSent = secondRequestSent
    }

    func send(request: URLRequest,
              completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
      lock.lock()
      _sentBodies.append(request.httpBody ?? Data())
      let requestCount = _sentBodies.count
      lock.unlock()

      // First request fails; later requests succeed (Persistence retry).
      if requestCount == 1 {
        firstRequestSent.fulfill()
        completion(.failure(SendFailure()))
      } else {
        secondRequestSent.fulfill()
        completion(.success(HTTPURLResponse(url: request.url!,
                                            statusCode: 200,
                                            httpVersion: "HTTP/1.1",
                                            headerFields: nil)!))
      }
    }

    func send(request: URLRequest) async throws -> HTTPURLResponse {
      try await withCheckedThrowingContinuation { continuation in
        send(request: request) { result in
          continuation.resume(with: result)
        }
      }
    }
  }

  override func setUp() {
    super.setUp()
    temporaryDirectory.create()
  }

  override func tearDown() {
    temporaryDirectory.delete()
    super.tearDown()
  }

  func testWhenExportFails_thenTheRetriedRequestCarriesOneCopyOfTheSpan() throws {
    let firstRequestSent = expectation(description: "first export attempt sent")
    let secondRequestSent = expectation(description: "second export attempt sent")
    let httpClient = FailOnceHTTPClient(firstRequestSent: firstRequestSent,
                                        secondRequestSent: secondRequestSent)

    let otlpExporter = OtlpHttpTraceExporter(config: OtlpConfiguration(compression: .none),
                                             httpClient: httpClient,
                                             envVarHeaders: nil,
                                             requeueOnFailure: false)

    let persistenceExporter = try PersistenceSpanExporterDecorator(
      spanExporter: otlpExporter,
      storageURL: temporaryDirectory.url,
      exportCondition: { true },
      performancePreset: PersistencePerformancePreset.mockWith(
        storagePerformance: StoragePerformanceMock.writeEachObjectToNewFileAndReadAllFiles,
        synchronousWrite: true,
        exportPerformance: ExportPerformanceMock.veryQuick))

    let tracerProviderSDK = TracerProviderSdk()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProviderSDK)
    let tracer = tracerProviderSDK.get(instrumentationName: "StackedOtlpHttpExporter") as! TracerSdk

    let spanProcessor = SimpleSpanProcessor(spanExporter: persistenceExporter)
    tracerProviderSDK.addSpanProcessor(spanProcessor)

    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    let spanContext = span.context
    span.end() // only writes to disk; the worker exports asynchronously.
    spanProcessor.shutdown() // flushes remaining disk batches so the failed span is retried synchronously.

    wait(for: [firstRequestSent, secondRequestSent], timeout: 10)

    let bodies = httpClient.sentBodies
    XCTAssertEqual(bodies.count, 2, "Expected the failed attempt and exactly one retry")

    let firstSpan = try singleSpan(in: bodies[0])
    let secondSpan = try singleSpan(in: bodies[1])
    XCTAssertEqual(firstSpan, secondSpan,
                   "The retried request must carry the same span, not a duplicate copy")
    assertSpanIdentity(firstSpan, matches: spanContext, name: "SimpleSpan")
  }

  private func singleSpan(in body: Data) throws -> Opentelemetry_Proto_Trace_V1_Span {
    let request = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest(serializedBytes: body)
    let spans = request.resourceSpans.flatMap(\.scopeSpans).flatMap(\.spans)
    guard spans.count == 1, let span = spans.first else {
      throw TestError.unexpectedSpanCount(spans.count)
    }
    return span
  }

  private func assertSpanIdentity(_ protoSpan: Opentelemetry_Proto_Trace_V1_Span,
                                  matches context: SpanContext,
                                  name: String,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) {
    var expectedTraceID = Data(count: TraceId.size)
    context.traceId.copyBytesTo(dest: &expectedTraceID, destOffset: 0)
    var expectedSpanID = Data(count: SpanId.size)
    context.spanId.copyBytesTo(dest: &expectedSpanID, destOffset: 0)
    XCTAssertEqual(protoSpan.traceID, expectedTraceID, file: file, line: line)
    XCTAssertEqual(protoSpan.spanID, expectedSpanID, file: file, line: line)
    XCTAssertEqual(protoSpan.name, name, file: file, line: line)
  }

  private enum TestError: Error {
    case unexpectedSpanCount(Int)
  }
}

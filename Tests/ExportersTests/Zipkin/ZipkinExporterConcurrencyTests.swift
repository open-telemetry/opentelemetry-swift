/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import SharedTestUtils
import XCTest
@testable import ZipkinExporter

/// Stress tests for the Zipkin span conversion, whose endpoint caches are
/// process-global. `export` is not exercised because it always hits the
/// network. They only run under Thread Sanitizer (or `OTEL_CONCURRENCY_TESTS=1`).
final class ZipkinExporterConcurrencyTests: XCTestCase {
  override func setUpWithError() throws {
    try ConcurrencyTesting.skipUnlessEnabled()
    ZipkinConversionExtension._resetCachesForTesting()
  }

  override func tearDown() {
    ZipkinConversionExtension._resetCachesForTesting()
  }

  private static func span(service: String, peer: String? = nil) -> SpanData {
    var attributes: [String: AttributeValue] = [:]
    if let peer {
      attributes["peer.service"] = .string(peer)
    }
    return TelemetryFixtures.spanData(name: "span",
                                      kind: peer == nil ? .server : .client,
                                      resource: Resource(attributes: ["service.name": .string(service)]),
                                      attributes: attributes)
  }

  func testConversionSharesEndpointCachesAcrossThreads() {
    let defaultEndpoint = ZipkinEndpoint(serviceName: "default")
    let wrongLocal = ConcurrentCounter()
    let wrongRemote = ConcurrentCounter()
    let threads = ConcurrencyTesting.defaultThreads

    ConcurrencyTesting.stress(threads: threads) { thread, iteration in
      // Half the threads collide on one service name, the rest use their own.
      let service = thread.isMultiple(of: 2) ? "shared-service" : "service-\(thread)"
      let peer = iteration.isMultiple(of: 2) ? "peer-\(thread)" : "shared-peer"
      let converted = ZipkinConversionExtension.toZipkinSpan(otelSpan: Self.span(service: service, peer: peer),
                                                             defaultLocalEndpoint: defaultEndpoint)
      if converted.localEndpoint?.serviceName != service {
        wrongLocal.increment()
      }
      if converted.remoteEndpoint?.serviceName != peer {
        wrongRemote.increment()
      }
    }

    XCTAssertEqual(wrongLocal.value, 0)
    XCTAssertEqual(wrongRemote.value, 0)
    let localCacheCount = ZipkinConversionExtension.localEndpointCacheLock.withLock {
      ZipkinConversionExtension.localEndpointCache.count
    }
    XCTAssertEqual(localCacheCount, 1 + threads / 2)
  }

  func testEncodeSpansFromManyThreadsThroughSharedExporter() {
    let exporter = UncheckedSendable(ZipkinTraceExporter(options: ZipkinTraceExporterOptions(endpoint: "http://localhost:9411/api/v2/spans")))
    let encoded = ConcurrentCounter()

    ConcurrencyTesting.stress { thread, _ in
      let spans = [Self.span(service: "service-\(thread)"), Self.span(service: "shared", peer: "peer")]
      encoded.increment(by: exporter.value.encodeSpans(spans: spans).count)
      _ = exporter.value.flush()
    }

    XCTAssertEqual(encoded.value, 2 * ConcurrencyTesting.defaultThreads * ConcurrencyTesting.defaultIterations)
  }
}

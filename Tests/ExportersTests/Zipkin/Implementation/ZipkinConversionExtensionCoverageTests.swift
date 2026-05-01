/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import ZipkinExporter
import XCTest

final class ZipkinConversionExtensionCoverageTests: XCTestCase {
  let defaultZipkinEndpoint = ZipkinEndpoint(serviceName: "TestService")

  // Build a span whose Resource carries service.name and service.namespace,
  // to exercise the local-endpoint override & namespace-tag branches in
  // toZipkinSpan that ZipkinSpanConverterTests doesn't cover.
  private func spanWithResourceAttributes(_ resourceAttrs: [String: AttributeValue],
                                          kind: SpanKind = .internal,
                                          attributes: [String: AttributeValue] = [:]) -> SpanData {
    let traceId = TraceId.random()
    let spanId = SpanId.random()
    let start = Date()
    let end = start.addingTimeInterval(1)
    return SpanData(traceId: traceId,
                    spanId: spanId,
                    parentSpanId: nil,
                    resource: Resource(attributes: resourceAttrs),
                    name: "n",
                    kind: kind,
                    startTime: start,
                    attributes: attributes,
                    events: [],
                    status: .ok,
                    endTime: end)
  }

  func testServiceNameFromResourceOverridesLocalEndpoint() {
    let span = spanWithResourceAttributes([
      SemanticConventions.Service.name.rawValue: .string("custom-svc")
    ])
    let zipkin = ZipkinConversionExtension.toZipkinSpan(
      otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertEqual(zipkin.localEndpoint?.serviceName, "custom-svc")
  }

  func testServiceNamespaceAddedAsTag() {
    let span = spanWithResourceAttributes([
      SemanticConventions.Service.namespace.rawValue: .string("ns")
    ])
    let zipkin = ZipkinConversionExtension.toZipkinSpan(
      otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertEqual(zipkin.tags["service.namespace"], "ns")
  }

  func testShortTraceIdEncodesLower64Bits() {
    let span = ZipkinSpanConverterTests.createTestSpan()
    let short = ZipkinConversionExtension.toZipkinSpan(otelSpan: span,
                                                       defaultLocalEndpoint: defaultZipkinEndpoint,
                                                       useShortTraceIds: true)
    XCTAssertEqual(short.traceId.count, 16)
  }

  func testNonClientProducerSpanHasNoRemoteEndpoint() {
    // remote endpoint resolution only runs for client/producer
    let span = spanWithResourceAttributes(
      [:],
      kind: .server,
      attributes: ["net.peer.name": .string("peer")])
    let zipkin = ZipkinConversionExtension.toZipkinSpan(
      otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertNil(zipkin.remoteEndpoint)
  }

  func testProducerSpanWithNetPeerNameResolvesRemote() {
    let span = spanWithResourceAttributes(
      [:],
      kind: .producer,
      attributes: ["net.peer.name": .string("peer-svc")])
    let zipkin = ZipkinConversionExtension.toZipkinSpan(
      otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertEqual(zipkin.remoteEndpoint?.serviceName, "peer-svc")
  }

  func testNonStringResourceAttributeSerializesViaDescription() {
    let span = spanWithResourceAttributes([
      "custom.resource-attr": .int(7)
    ])
    let zipkin = ZipkinConversionExtension.toZipkinSpan(
      otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    // Non-string resource attribute takes the value.description fallback.
    XCTAssertNotNil(zipkin.tags["custom.resource-attr"])
  }

  func testNonStringSpanAttributeUsesDescription() {
    let span = spanWithResourceAttributes(
      [:], kind: .internal,
      attributes: ["x": .int(99)])
    let zipkin = ZipkinConversionExtension.toZipkinSpan(
      otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertNotNil(zipkin.tags["x"])
  }
}

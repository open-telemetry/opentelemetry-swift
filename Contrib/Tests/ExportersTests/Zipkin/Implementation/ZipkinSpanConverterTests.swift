/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest
@testable import ZipkinExporter

class ZipkinSpanConverterTests: XCTestCase {
  let defaultZipkinEndpoint = ZipkinEndpoint(serviceName: "TestService")

  func testGenerateSpanRemoteEndpointOmittedByDefault() {
    let span = ZipkinSpanConverterTests.createTestSpan()
    let zipkinSpan = ZipkinConversionExtension.toZipkinSpan(otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertNil(zipkinSpan.remoteEndpoint)
  }

  func testGenerateSpanRemoteEndpointResolution() {
    let span = ZipkinSpanConverterTests.createTestSpan(additionalAttributes: ["net.peer.name": "RemoteServiceName"])
    let zipkinSpan = ZipkinConversionExtension.toZipkinSpan(otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertNotNil(zipkinSpan.remoteEndpoint)
    XCTAssertEqual(zipkinSpan.remoteEndpoint?.serviceName, "RemoteServiceName")
  }

  func testGenerateSpanRemoteEndpointResolutionPriority() {
    let span = ZipkinSpanConverterTests.createTestSpan(additionalAttributes: ["http.host": "DiscardedRemoteServiceName",
                                                                              "net.peer.name": "RemoteServiceName",
                                                                              "peer.hostname": "DiscardedRemoteServiceName"])
    let zipkinSpan = ZipkinConversionExtension.toZipkinSpan(otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertNotNil(zipkinSpan.remoteEndpoint)
    XCTAssertEqual(zipkinSpan.remoteEndpoint?.serviceName, "RemoteServiceName")
  }

  func testStatusUnset() {
    let span = ZipkinSpanConverterTests.createTestSpan(status: Status.unset)
    let zipkinSpan = ZipkinConversionExtension.toZipkinSpan(otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertNil(zipkinSpan.tags["otel.status_code"])
  }

  func testStatusError() {
    let span = ZipkinSpanConverterTests.createTestSpan(status: Status.error(description: "error message"))
    let zipkinSpan = ZipkinConversionExtension.toZipkinSpan(otelSpan: span, defaultLocalEndpoint: defaultZipkinEndpoint)
    XCTAssertEqual(zipkinSpan.tags["otel.status_code"], "ERROR")
    XCTAssertEqual(zipkinSpan.tags["error"], "error message")
  }

  public static func createTestSpan(setAttributes: Bool = true, additionalAttributes: [String: Any]? = nil, addEvents: Bool = true, addLinks: Bool = true, status: Status = Status.ok) -> SpanData {
    let startTimestamp = Date(timeIntervalSince1970: Double(Int(Date().timeIntervalSince1970))) // Round for comparison
    let endTimestamp = startTimestamp.addingTimeInterval(60)
    let eventTimestamp = startTimestamp
    let traceId = TraceId(fromHexString: "e8ea7e9ac72de94e91fabc613f9686b2")

    let spanId = SpanId.random()
    let parentSpanId = SpanId(fromBytes: [12, 23, 34, 45, 56, 67, 78, 89])
    var attributes: [String: AttributeValue] = ["stringKey": AttributeValue.string("value"),
                                                "longKey": AttributeValue.int(1),
                                                "longKey2": AttributeValue.int(1),
                                                "doubleKey": AttributeValue.double(1.0),
                                                "doubleKey2": AttributeValue.double(1.0),
                                                "boolKey": AttributeValue.bool(true)]

    additionalAttributes?.forEach {
      attributes[$0.key] = AttributeValue($0.value)
    }

    let events: [SpanData.Event] = [SpanData.Event(name: "Event1", timestamp: eventTimestamp, attributes: ["key": AttributeValue.string("value")]),
                                    SpanData.Event(name: "Event2", timestamp: eventTimestamp, attributes: ["key": AttributeValue.string("value")])]

//        let linkedSpanId = SpanId(fromHexString: "888915b6286b9c41")

    return SpanData(traceId: traceId, spanId: spanId, parentSpanId: parentSpanId, resource: Resource.empty, name: "Name", kind: .client, startTime: startTimestamp, attributes: attributes, events: events, status: status, endTime: endTimestamp)
  }
}

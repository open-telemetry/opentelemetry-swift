/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import FaroExporter
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetrySdk
import XCTest

final class FaroSpanAdapterTests: XCTestCase {
  let traceIdBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4]
  var traceId: TraceId!
  let spanIdBytes: [UInt8] = [0, 0, 0, 0, 4, 3, 2, 1]
  var spanId: SpanId!

  override func setUp() {
    super.setUp()
    traceId = TraceId(fromBytes: traceIdBytes)
    spanId = SpanId(fromBytes: spanIdBytes)
  }

  func testToProtoResourceSpans_EmptyList() {
    // When
    let result = FaroSpanAdapter.toProtoResourceSpans(spanDataList: [], sessionId: "test-session-id")

    // Then
    XCTAssertTrue(result.isEmpty, "Should return empty list for empty input")
  }

  func testToProtoResourceSpans_AddSessionIdAttributes() {
    // Given
    let startTime = Date(timeIntervalSince1970: 12345)
    let endTime = Date(timeIntervalSince1970: 12349)
    let sessionId = "test-session-id"

    let testSpan = createTestSpan(
      name: "test-span",
      attributes: ["existing-key": AttributeValue.string("existing-value")],
      startTime: startTime,
      endTime: endTime
    )
    let spanDataList: [SpanData] = [testSpan]

    // When
    let result = FaroSpanAdapter.toProtoResourceSpans(spanDataList: spanDataList, sessionId: sessionId)

    // Then
    XCTAssertFalse(result.isEmpty, "Should return non-empty list")

    var expectedAttributes = testSpan.attributes
    expectedAttributes["session_id"] = AttributeValue.string(sessionId)
    expectedAttributes["session.id"] = AttributeValue.string(sessionId)

    var expectedSpan = testSpan
    expectedSpan = expectedSpan.settingAttributes(expectedAttributes)
    expectedSpan = expectedSpan.settingTotalAttributeCount(testSpan.totalAttributeCount + 2)

    XCTAssertEqual(result.count, spanDataList.count, "Should have same number of spans")

    // Extract all attributes from the result for verification
    let attributes = result[0].scopeSpans[0].spans[0].attributes
    let foundAttributesMap = Dictionary(attributes.map { ($0.key, $0.value.value) }, uniquingKeysWith: { first, _ in first })

    verifyAttribute(key: "session.id", in: foundAttributesMap, hasStringValue: sessionId)
    verifyAttribute(key: "session_id", in: foundAttributesMap, hasStringValue: sessionId)
  }

  func testToProtoResourceSpans_PreservesExistingAttributes() {
    // Given
    let sessionId = "test-session-id"
    let originalAttributes: [String: AttributeValue] = [
      "key1": AttributeValue.string("value1"),
      "key2": AttributeValue.int(42),
      "key3": AttributeValue.bool(true)
    ]

    let testSpan = createTestSpan(
      name: "test-span",
      attributes: originalAttributes
    )

    // When
    let result = FaroSpanAdapter.toProtoResourceSpans(spanDataList: [testSpan], sessionId: sessionId)

    // Then
    XCTAssertFalse(result.isEmpty, "Should return non-empty list")

    // Extract all attributes from the result for verification
    let attributes = result[0].scopeSpans[0].spans[0].attributes
    let foundAttributesMap = Dictionary(attributes.map { ($0.key, $0.value.value) }, uniquingKeysWith: { first, _ in first })

    // Verify all original attributes are preserved
    XCTAssertEqual(foundAttributesMap.count, originalAttributes.count + 2, "Should have original attributes plus 2 session IDs")

    // Verify each attribute has the correct type and value
    verifyAttribute(key: "key1", in: foundAttributesMap, hasStringValue: "value1")
    verifyAttribute(key: "key2", in: foundAttributesMap, hasIntValue: 42)
    verifyAttribute(key: "key3", in: foundAttributesMap, hasBoolValue: true)
  }

  func testToProtoResourceSpans_MultipleSpans() {
    // Given
    let sessionId = "test-session-id"
    let spans = [
      createTestSpan(name: "span1", attributes: ["span": AttributeValue.string("1")]),
      createTestSpan(name: "span2", attributes: ["span": AttributeValue.string("2")]),
      createTestSpan(name: "span3", attributes: ["span": AttributeValue.string("3")])
    ]

    // When
    let result = FaroSpanAdapter.toProtoResourceSpans(spanDataList: spans, sessionId: sessionId)

    // Then
    XCTAssertFalse(result.isEmpty, "Should return non-empty list")
    XCTAssertEqual(result.count, 1, "Should group spans under one resource")

    let resourceSpan = result[0]
    XCTAssertEqual(resourceSpan.scopeSpans.count, 1, "Should group spans under one scope")

    let scopeSpans = resourceSpan.scopeSpans[0]
    XCTAssertEqual(scopeSpans.spans.count, spans.count, "Should have same number of spans")

    // Create a dictionary mapping span names to their attributes for easier verification
    var spanAttributeMap = [String: [String: Opentelemetry_Proto_Common_V1_AnyValue.OneOf_Value?]]()

    for span in scopeSpans.spans {
      let attributes = Dictionary(span.attributes.map { ($0.key, $0.value.value) }, uniquingKeysWith: { first, _ in first })
      spanAttributeMap[span.name] = attributes
    }

    // Verify all spans exist with correct attributes
    XCTAssertTrue(spanAttributeMap.keys.contains("span1"), "span1 should exist in result")
    XCTAssertTrue(spanAttributeMap.keys.contains("span2"), "span2 should exist in result")
    XCTAssertTrue(spanAttributeMap.keys.contains("span3"), "span3 should exist in result")

    verifyAttribute(key: "span", in: spanAttributeMap["span1"]!, hasStringValue: "1")
    verifyAttribute(key: "span", in: spanAttributeMap["span2"]!, hasStringValue: "2")
    verifyAttribute(key: "span", in: spanAttributeMap["span3"]!, hasStringValue: "3")
  }

  // MARK: - Helpers

  private func createTestSpan(name: String = "test-span",
                              kind: SpanKind = .internal,
                              attributes: [String: AttributeValue] = [:],
                              startTime: Date? = nil,
                              endTime: Date? = nil) -> SpanData {
    let start = startTime ?? Date()
    let end = endTime ?? Date(timeIntervalSinceNow: 0.1)

    var span = SpanData(
      traceId: traceId,
      spanId: spanId,
      name: name,
      kind: kind,
      startTime: start,
      endTime: end
    )
    span.settingAttributes(attributes)
    span.settingTotalAttributeCount(attributes.count)
    return span
  }

  // MARK: - Additional Helpers

  private func verifyAttribute(key: String, in attributes: [String: Opentelemetry_Proto_Common_V1_AnyValue.OneOf_Value?], hasStringValue expectedValue: String) {
    guard case let .stringValue(value)? = attributes[key] else {
      XCTFail("Attribute \(key) not found or not a string")
      return
    }
    XCTAssertEqual(value, expectedValue, "String attribute \(key) should have value \(expectedValue)")
  }

  private func verifyAttribute(key: String, in attributes: [String: Opentelemetry_Proto_Common_V1_AnyValue.OneOf_Value?], hasIntValue expectedValue: Int64) {
    guard case let .intValue(value)? = attributes[key] else {
      XCTFail("Attribute \(key) not found or not an integer")
      return
    }
    XCTAssertEqual(value, expectedValue, "Int attribute \(key) should have value \(expectedValue)")
  }

  private func verifyAttribute(key: String, in attributes: [String: Opentelemetry_Proto_Common_V1_AnyValue.OneOf_Value?], hasBoolValue expectedValue: Bool) {
    guard case let .boolValue(value)? = attributes[key] else {
      XCTFail("Attribute \(key) not found or not a boolean")
      return
    }
    XCTAssertEqual(value, expectedValue, "Bool attribute \(key) should have value \(expectedValue)")
  }
}

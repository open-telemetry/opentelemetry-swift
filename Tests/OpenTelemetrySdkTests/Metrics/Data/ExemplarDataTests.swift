//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class ExemplarDataTests: XCTestCase {
  func testExemplarDataCreation() {
    let epochNanos: UInt64 = 0
    let filteredAttributes = [String: AttributeValue]()

    let exemplarData = ExemplarData(epochNanos: epochNanos, filteredAttributes: filteredAttributes)

    XCTAssertEqual(exemplarData.epochNanos, epochNanos)
    XCTAssertEqual(exemplarData.filteredAttributes, filteredAttributes)
  }

  func testDoubleCodable() {
    let origin = DoubleExemplarData(value: 12.0,
                                    epochNanos: 1,
                                    filteredAttributes: ["hello": AttributeValue.string("world")])

    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(origin)
      let decoded: DoubleExemplarData = try JSONDecoder().decode(DoubleExemplarData.self, from: data)
      XCTAssertTrue(decoded == origin)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }

  func testLongCodable() {
    let origin = LongExemplarData(value: 12,
                                  epochNanos: 1,
                                  filteredAttributes: ["hello": AttributeValue.string("world")])

    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(origin)
      let decoded = try JSONDecoder().decode(LongExemplarData.self, from: data)
      XCTAssertTrue(decoded == origin)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }

  func testExemplarDataCreationContext() {
    let epochNanos: UInt64 = 3
    let filteredAttributes = ["foo": AttributeValue("bar")]

    let traceIdBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]
    let spanIdBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]
    let spanContext = SpanContext.create(traceId: TraceId(fromBytes: traceIdBytes), spanId: SpanId(fromBytes: spanIdBytes), traceFlags: TraceFlags(), traceState: TraceState())

    let exemplarData = ExemplarData(epochNanos: epochNanos, filteredAttributes: filteredAttributes, spanContext: spanContext)

    XCTAssertEqual(exemplarData.epochNanos, epochNanos)
    XCTAssertEqual(exemplarData.filteredAttributes, filteredAttributes)
    XCTAssertEqual(exemplarData.spanContext, spanContext)
  }

  func testDoubleExemplarDataCreation() {
    let doubleValue = 3.14
    let epochNanos: UInt64 = 0
    let filteredAttributes = [String: AttributeValue]()

    let exemplarData = DoubleExemplarData(value: doubleValue, epochNanos: epochNanos, filteredAttributes: filteredAttributes)

    XCTAssertEqual(exemplarData.epochNanos, epochNanos)
    XCTAssertEqual(exemplarData.filteredAttributes, filteredAttributes)
    XCTAssertEqual(exemplarData.value, doubleValue)
  }

  func testLongExemplarDataCreation() {
    let longValue = 314
    let epochNanos: UInt64 = 0
    let filteredAttributes = [String: AttributeValue]()

    let exemplarData = LongExemplarData(value: longValue, epochNanos: epochNanos, filteredAttributes: filteredAttributes)

    XCTAssertEqual(exemplarData.epochNanos, epochNanos)
    XCTAssertEqual(exemplarData.filteredAttributes, filteredAttributes)
    XCTAssertEqual(exemplarData.value, longValue)
  }
}

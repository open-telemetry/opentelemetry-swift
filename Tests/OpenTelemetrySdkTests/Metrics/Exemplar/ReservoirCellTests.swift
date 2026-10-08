//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class ReservoirCellTests: XCTestCase {
  let idGen = RandomIdGenerator()
  var reservoirCell: ReservoirCell!
  let mockClock = TestClock()

  override func setUp() {
    super.setUp()
    reservoirCell = ReservoirCell(clock: mockClock)
  }

  func testRecordLongValue() {
    let attributes = ["attribute1": AttributeValue.string("value1")]
    reservoirCell.recordLongValue(value: 10, attributes: attributes)

    XCTAssertEqual(reservoirCell.longValue, 10)
    XCTAssertEqual(reservoirCell.attributes.protectedValue, attributes)
    XCTAssertEqual(reservoirCell.spanContext, nil)
  }

  func testRecordDoubleValue() {
    let attributes = ["attribute1": AttributeValue.string("value1")]
    reservoirCell.recordDoubleValue(value: 3.14, attributes: attributes)

    XCTAssertEqual(reservoirCell.doubleValue, 3.14)
    XCTAssertEqual(reservoirCell.attributes.protectedValue, attributes)
    XCTAssertEqual(reservoirCell.spanContext, nil)
  }

  func testGetAndResetLong() {
    let attributes = ["attribute1": AttributeValue.string("value1")]
    let pointAttributes = ["attribute2": AttributeValue.string("value2")]
    reservoirCell.recordLongValue(value: 10, attributes: attributes)

    let result = reservoirCell.getAndResetLong(pointAttributes: pointAttributes)
    XCTAssertEqual(result?.value, 10)
    XCTAssertEqual(result?.epochNanos, mockClock.nanoTime)
    XCTAssertEqual(result?.filteredAttributes, attributes)
    XCTAssertEqual(result?.spanContext, nil)

    XCTAssertEqual(reservoirCell.attributes.protectedValue, [:])
    XCTAssertEqual(reservoirCell.longValue, 0)
    XCTAssertEqual(reservoirCell.spanContext, nil)
    XCTAssertEqual(reservoirCell.recordTime, 0)
  }

  func testGetAndResetDouble() {
    let attributes = ["attribute1": AttributeValue.string("value1")]
    let pointAttributes = ["attribute2": AttributeValue.string("value2")]
    reservoirCell.recordDoubleValue(value: 3.14, attributes: attributes)

    let result = reservoirCell.getAndResetDouble(pointAttributes: pointAttributes)
    XCTAssertEqual(result?.value, 3.14)
    XCTAssertEqual(result?.epochNanos, mockClock.nanoTime)
    XCTAssertEqual(result?.filteredAttributes, attributes)
    XCTAssertEqual(result?.spanContext, nil)

    XCTAssertEqual(reservoirCell.attributes.protectedValue, [:])
    XCTAssertEqual(reservoirCell.doubleValue, 0)
    XCTAssertEqual(reservoirCell.spanContext, nil)
    XCTAssertEqual(reservoirCell.recordTime, 0)
  }

  func testReset() {
    let attributes = ["attribute1": AttributeValue.string("value1")]
    reservoirCell.recordLongValue(value: 10, attributes: attributes)

    reservoirCell.reset()

    XCTAssertEqual(reservoirCell.attributes.protectedValue, [:])
    XCTAssertEqual(reservoirCell.longValue, 0)
    XCTAssertEqual(reservoirCell.doubleValue, 0)
    XCTAssertEqual(reservoirCell.spanContext, nil)
    XCTAssertEqual(reservoirCell.recordTime, 0)
  }

  func testFiltered() {
    let originalAttributes: [String: AttributeValue] = [
      "key1": .string("value1"),
      "key2": .int(123),
      "key3": .bool(true)
    ]
    let metricPointAttributes: [String: AttributeValue] = [
      "key2": .int(123),
      "key4": .string("value4")
    ]
    let expectedFilteredAttributes: [String: AttributeValue] = [
      "key1": .string("value1"),
      "key3": .bool(true)
    ]

    let filteredAttributes = reservoirCell.filtered(originalAttributes, metricPointAttributes)

    XCTAssertEqual(filteredAttributes, expectedFilteredAttributes)
  }
}

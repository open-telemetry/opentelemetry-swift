//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class ReservoirCellSelectorMock: ReservoirCellSelector {
  func reservoirCellIndex(for cells: [ReservoirCell], value: Int, attributes: [String: AttributeValue]) -> Int {
    return cells.firstIndex { $0.longValue == 0 } ?? 0
  }

  func reservoirCellIndex(for cells: [ReservoirCell], value: Double, attributes: [String: AttributeValue]) -> Int {
    return cells.firstIndex { $0.doubleValue == 0.0 } ?? 0
  }

  func reset() {
    // do nothing for testing purposes
  }
}

class FixedSizedExemplarReservoirTests: XCTestCase {
  var reservoir: FixedSizedExemplarReservoir!
  let clock = TestClock()
  let attributes: [String: AttributeValue] = ["key1": AttributeValue("value1"), "key2": AttributeValue("value2")]
  let selector = ReservoirCellSelectorMock()

  override func setUp() {
    super.setUp()
    reservoir = FixedSizedExemplarReservoir(clock: clock, size: 4, reservoirCellSelector: selector, mapAndResetCell: { cell, attributes in cell.getAndResetDouble(pointAttributes: attributes)
    })
  }

  func testOfferLongMeasurement() {
    reservoir.offerLongMeasurement(value: 1, attributes: attributes)
    reservoir.offerLongMeasurement(value: 2, attributes: attributes)
    reservoir.offerLongMeasurement(value: 3, attributes: attributes)
    reservoir.offerLongMeasurement(value: 4, attributes: attributes)

    XCTAssertTrue(reservoir.storage.contains { $0.longValue == 1 })
    XCTAssertTrue(reservoir.storage.contains { $0.longValue == 2 })
    XCTAssertTrue(reservoir.storage.contains { $0.longValue == 3 })
    XCTAssertTrue(reservoir.storage.contains { $0.longValue == 4 })
  }

  func testOfferDoubleMeasurement() {
    reservoir.offerDoubleMeasurement(value: 1.1, attributes: attributes)
    reservoir.offerDoubleMeasurement(value: 2.2, attributes: attributes)
    reservoir.offerDoubleMeasurement(value: 3.3, attributes: attributes)
    reservoir.offerDoubleMeasurement(value: 4.4, attributes: attributes)

    XCTAssertTrue(reservoir.storage.contains { $0.doubleValue == 1.1 })
    XCTAssertTrue(reservoir.storage.contains { $0.doubleValue == 2.2 })
    XCTAssertTrue(reservoir.storage.contains { $0.doubleValue == 3.3 })
    XCTAssertTrue(reservoir.storage.contains { $0.doubleValue == 4.4 })
  }

  func testPartiallyFullReservoir() {
    reservoir.offerDoubleMeasurement(value: 1.1, attributes: attributes)
    let result = reservoir.collectAndReset(attribute: attributes)
    XCTAssertEqual(result.count, 1)
    XCTAssertTrue(result.contains(where: { exemplarData in
      (exemplarData as! DoubleExemplarData).value == 1.1
    }))
    XCTAssertFalse(reservoir.storage.contains { $0.doubleValue == 1.1 })
  }

  func testCollectAndReset() {
    let clock = TestClock()
    let reservoirSize = 6
    let reservoirCellSelector = ReservoirCellSelectorMock()

    // Create the reservoir
    let reservoir = FixedSizedExemplarReservoir(clock: clock, size: reservoirSize, reservoirCellSelector: reservoirCellSelector, mapAndResetCell: { cell, attributes in
      let exemplar = cell.getAndResetLong(pointAttributes: attributes)
      return exemplar?.value ?? 0 > 0 ? exemplar : nil
    })

    // Offer measurements
    reservoir.offerLongMeasurement(value: 100, attributes: ["service": AttributeValue.string("foo")])
    reservoir.offerLongMeasurement(value: 200, attributes: ["service": AttributeValue.string("foo")])
    reservoir.offerLongMeasurement(value: 300, attributes: ["service": AttributeValue.string("bar")])
    reservoir.offerLongMeasurement(value: 400, attributes: ["service": AttributeValue.string("bar")])
    reservoir.offerLongMeasurement(value: 500, attributes: ["service": AttributeValue.string("baz")])
    reservoir.offerLongMeasurement(value: 0, attributes: [:])

    // Collect and reset with empty attributes
    var exemplars = reservoir.collectAndReset(attribute: [:])
    XCTAssertEqual(exemplars.count, 5)

    // Collect and reset with non-empty attributes
    exemplars = reservoir.collectAndReset(attribute: ["service": AttributeValue.string("bar")])
    XCTAssertEqual(exemplars.count, 0)

    // Collect and reset with attributes that don't match any measurements
    exemplars = reservoir.collectAndReset(attribute: ["service": AttributeValue.string("qux")])
    XCTAssertEqual(exemplars.count, 0)

    // Offer new measurements
    reservoir.offerLongMeasurement(value: 600, attributes: ["service": AttributeValue.string("foo")])
    reservoir.offerLongMeasurement(value: 700, attributes: ["service": AttributeValue.string("foo")])
    reservoir.offerLongMeasurement(value: 800, attributes: ["service": AttributeValue.string("foo")])
    reservoir.offerLongMeasurement(value: 900, attributes: ["service": AttributeValue.string("foo")])

    // Collect and reset again with empty attributes
    exemplars = reservoir.collectAndReset(attribute: [:])
    XCTAssertEqual(exemplars.count, 4)
  }
}

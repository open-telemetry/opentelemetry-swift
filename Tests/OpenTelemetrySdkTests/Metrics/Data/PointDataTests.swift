//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class PointDataTests: XCTestCase {
  func testPointDataCreation() {
    let startEpochNanos: UInt64 = 1
    let endEpochNanos: UInt64 = 3
    let attributes = ["foo": AttributeValue("bar")]
    let auxExemplars = [DoubleExemplarData(value: 3.14, epochNanos: 2, filteredAttributes: [:])]

    let pointData = PointData(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: auxExemplars)

    XCTAssertEqual(pointData.startEpochNanos, startEpochNanos)
    XCTAssertEqual(pointData.endEpochNanos, endEpochNanos)
    XCTAssertEqual(pointData.attributes, attributes)
    XCTAssertEqual(pointData.exemplars, auxExemplars)
  }

  func testDiffReturnsFirstValue() {
    let startEpochNanos1: UInt64 = 1
    let endEpochNanos1: UInt64 = 3
    let attributes1 = ["foo1": AttributeValue("bar1")]
    let auxExemplars1 = [DoubleExemplarData(value: 3.14, epochNanos: 2, filteredAttributes: [:])]

    let pointData1 = PointData(startEpochNanos: startEpochNanos1, endEpochNanos: endEpochNanos1, attributes: attributes1, exemplars: auxExemplars1)

    let startEpochNanos2: UInt64 = 10
    let endEpochNanos2: UInt64 = 30
    let attributes2 = ["foo2": AttributeValue("bar2")]
    let auxExemplars2 = [DoubleExemplarData(value: 8.5, epochNanos: 10, filteredAttributes: ["some": AttributeValue("value")])]

    let pointData2 = PointData(startEpochNanos: startEpochNanos2, endEpochNanos: endEpochNanos2, attributes: attributes2, exemplars: auxExemplars2)

    XCTAssertEqual(pointData1 - pointData2, pointData1)
    XCTAssertEqual(pointData2 - pointData1, pointData2)
  }
}

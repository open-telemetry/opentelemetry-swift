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

  func testHistogramPointDataCodable() {
    let origin = HistogramPointData(
      startEpochNanos: 1,
      endEpochNanos: 2,
      attributes: ["hello": AttributeValue.string("world")],
      exemplars: [DoubleExemplarData(value: 1.2, epochNanos: 1, filteredAttributes: ["hello": AttributeValue.string("world")])],
      sum: 22.22,
      count: 15,
      min: 1,
      max: 100,
      boundaries: [1, 3, 5, 8],
      counts: [1, 1, 1, 1],
      hasMin: true,
      hasMax: true
    )

    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(origin)
      let decoded = try JSONDecoder().decode(HistogramPointData.self, from: data)
      XCTAssertEqual(decoded, origin)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }

  func testExponentialHistogramPointDataCodable() {
    let origin = ExponentialHistogramPointData(
      scale: 1,
      sum: 2,
      zeroCount: 111,
      hasMin: true,
      hasMax: true,
      min: 0.0,
      max: 1.0,
      positiveBuckets: EmptyExponentialHistogramBuckets(scale: 1),
      negativeBuckets: DoubleBase2ExponentialHistogramBuckets(
        scale: 1,
        maxBuckets: 100
      ),
      startEpochNanos: 1111,
      epochNanos: 123123123,
      attributes: ["hello": AttributeValue.string("world")],
      exemplars: [DoubleExemplarData(value: 1.2, epochNanos: 1, filteredAttributes: ["hello": AttributeValue.string("world")])]
    )

    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(origin)
      let decoded = try JSONDecoder().decode(ExponentialHistogramPointData.self, from: data)
      XCTAssertEqual(decoded, origin)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }

  func testLongPointDataCodable() {
    let origin = LongPointData(
      startEpochNanos: 2,
      endEpochNanos: 1,
      attributes: ["hello": AttributeValue.string("world")],
      exemplars: [LongExemplarData(
        value: 1,
        epochNanos: 1,
        filteredAttributes: ["hello": AttributeValue.string("world")]
      )],
      value: 100
    )

    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(origin)
      let decoded = try JSONDecoder().decode(LongPointData.self, from: data)
      XCTAssertEqual(decoded, origin)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }

  func testDoublePointDataCodable() {
    let origin = DoublePointData(
      startEpochNanos: 2,
      endEpochNanos: 1,
      attributes: ["hello": AttributeValue.string("world")],
      exemplars: [DoubleExemplarData(
        value: 1.0,
        epochNanos: 1,
        filteredAttributes: ["hello": AttributeValue.string("world")]
      )],
      value: 100.1
    )
    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(origin)
      let decoded = try JSONDecoder().decode(DoublePointData.self, from: data)
      XCTAssertEqual(decoded, origin)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }

  func testSummaryPointDataCodable() {
    let origin = SummaryPointData(startEpochNanos: 2,
                                  endEpochNanos: 1,
                                  attributes: ["hello": AttributeValue.string("world")],
                                  count: 100,
                                  sum: 2.2,
                                  percentileValues: [ValueAtQuantile(quantile: 1.1, value: 1.3)])

    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(origin)
      let decoded = try JSONDecoder().decode(SummaryPointData.self, from: data)
      XCTAssertEqual(decoded, origin)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
}

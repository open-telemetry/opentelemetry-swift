//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class DoubleExplicitBucketHistogramAggregatorTests: XCTestCase {
  // Test the creation of a new handle
  func testCreateHandle() {
    let aggregator = DoubleExplicitBucketHistogramAggregator(boundaries: [1.0, 2.0], reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle() as! DoubleExplicitBucketHistogramAggregator.Handle
    XCTAssertEqual(handle.count, 0)
    XCTAssertEqual(handle.sum, 0)
    XCTAssertEqual(handle.min, Double.greatestFiniteMagnitude)
    XCTAssertEqual(handle.max, -1)
    XCTAssertEqual(handle.counts, [0, 0, 0])
    XCTAssertEqual(handle.boundaries, [1.0, 2.0])
  }

  // Test the aggregation of double values
  func testDoRecordDouble() {
    let aggregator = DoubleExplicitBucketHistogramAggregator(boundaries: [1.0, 2.0], reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle() as! DoubleExplicitBucketHistogramAggregator.Handle
    handle.recordDouble(value: 1.5)
    handle.recordDouble(value: 2.5)

    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1, attributes: [:], reset: false) as! HistogramPointData

    XCTAssertEqual(pointData.sum, 4.0)
    XCTAssertEqual(pointData.count, 2)
    XCTAssertEqual(pointData.min, 1.5)
    XCTAssertEqual(pointData.max, 2.5)
    XCTAssertEqual(pointData.counts, [0, 1, 1])
    XCTAssertEqual(pointData.boundaries, [1.0, 2.0])
    XCTAssertEqual(pointData.hasMin, true)
    XCTAssertEqual(pointData.hasMax, true)
  }

  // Test the aggregation of long values
  func testDoRecordLong() {
    let aggregator = DoubleExplicitBucketHistogramAggregator(boundaries: [1.0, 2.0], reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle()
    handle.recordLong(value: 1)
    handle.recordLong(value: 3)

    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1, attributes: [:], reset: false) as! HistogramPointData

    XCTAssertEqual(pointData.sum, 4.0)
    XCTAssertEqual(pointData.count, 2)
    XCTAssertEqual(pointData.min, 1.0)
    XCTAssertEqual(pointData.max, 3.0)
    XCTAssertEqual(pointData.counts, [1, 0, 1])
    XCTAssertEqual(pointData.boundaries, [1.0, 2.0])
    XCTAssertEqual(pointData.hasMin, true)
    XCTAssertEqual(pointData.hasMax, true)
  }

  // Test the aggregation of double values and reset of the handle
  func testAggregateThenMaybeReset() {
    let aggregator = DoubleExplicitBucketHistogramAggregator(boundaries: [0.5, 1.0, 2.0], reservoirSupplier: { NoopExemplarReservoir() })
    let handle = aggregator.createHandle()
    handle.recordDouble(value: 1.5)
    handle.recordDouble(value: 0.25)
    handle.recordDouble(value: 0.75)

    // Aggregate without resetting
    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1000, attributes: [:], reset: false) as! HistogramPointData
    XCTAssertEqual(pointData.sum, 2.5)
    XCTAssertEqual(pointData.count, 3)
    XCTAssertEqual(pointData.min, 0.25)
    XCTAssertEqual(pointData.max, 1.5)
    XCTAssertEqual(pointData.counts, [1, 1, 1, 0])

    // Aggregate and reset
    let pointData2 = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1000, attributes: [:], reset: true) as! HistogramPointData
    XCTAssertEqual(pointData2.sum, 2.5)
    XCTAssertEqual(pointData2.count, 3)
    XCTAssertEqual(pointData2.min, 0.25)
    XCTAssertEqual(pointData2.max, 1.5)
    XCTAssertEqual(pointData2.counts, [1, 1, 1, 0])

    // Aggregate after reset
    let pointData3 = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1000, attributes: [:], reset: false) as! HistogramPointData
    XCTAssertEqual(pointData3.sum, 0)
    XCTAssertEqual(pointData3.count, 0)
    XCTAssertEqual(pointData3.min, Double.greatestFiniteMagnitude)
    XCTAssertEqual(pointData3.max, -1)
    XCTAssertEqual(pointData3.counts, [0, 0, 0, 0])
  }

  func testDiff() {
    // Initialize aggregator
    let aggregator = DoubleExplicitBucketHistogramAggregator(boundaries: [1.0, 2.0, 3.0], reservoirSupplier: { NoopExemplarReservoir() })

    // Create some dummy PointData objects
    let previousCumulative = HistogramPointData(startEpochNanos: 0, endEpochNanos: 100, attributes: [:], exemplars: [], sum: 10.0, count: 1, min: 5.0, max: 5.0, boundaries: [], counts: [], hasMin: true, hasMax: true)
    let currentCumulative = HistogramPointData(startEpochNanos: 0, endEpochNanos: 200, attributes: [:], exemplars: [], sum: 20.0, count: 2, min: 3.0, max: 7.0, boundaries: [], counts: [], hasMin: true, hasMax: true)

    // Verify that the diff() method throws the expected error
    XCTAssertThrowsError(try aggregator.diff(previousCumulative: previousCumulative, currentCumulative: currentCumulative))
  }
}

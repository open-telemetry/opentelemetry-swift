//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class DoubleBase2ExponentialHistogramAggregatorTests: XCTestCase {
  let reservoir = LongToDoubleExemplarReservoir(reservoir: RandomFixedSizedExemplarReservoir.createDouble(clock: MillisClock(), size: 2))

  func valueToIndex(scale: Int, value: Double) -> Int {
    let scaleFactor = (1.0 / log(2)) * pow(2.0, Double(scale))
    return Int(ceil(log(value) * scaleFactor) - 1)
  }

  func testCreateHandle() {
    let aggregator = DoubleBase2ExponentialHistogramAggregator(maxBuckets: 150, maxScale: 10, reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle() as! DoubleBase2ExponentialHistogramAggregator.Handle

    XCTAssertEqual(handle.maxBuckets, 150)
    XCTAssertEqual(handle.maxScale, 10)
    XCTAssertEqual(handle.zeroCount, 0)
    XCTAssertEqual(handle.min, Double.greatestFiniteMagnitude)
    XCTAssertEqual(handle.max, -1)
    XCTAssertEqual(handle.count, 0)
    XCTAssertEqual(handle.scale, 10)
  }

  func testDoRecordDouble() {
    let aggregator = DoubleBase2ExponentialHistogramAggregator(maxBuckets: 160, maxScale: 20, reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle() as! DoubleBase2ExponentialHistogramAggregator.Handle

    handle.doRecordDouble(value: 0.5)
    handle.doRecordDouble(value: 1.0)
    handle.doRecordDouble(value: 12.0)
    handle.doRecordDouble(value: 15.213)
    handle.doRecordDouble(value: 12.0)
    handle.doRecordDouble(value: -13.2)
    handle.doRecordDouble(value: -2.01)
    handle.doRecordDouble(value: -1)
    handle.doRecordDouble(value: 0.0)
    handle.doRecordDouble(value: 0)

    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1, attributes: [:], reset: false) as! ExponentialHistogramPointData
    let expectedScale = 5
    let positiveCounts = pointData.positiveBuckets.bucketCounts
    let negativeCounts = pointData.negativeBuckets.bucketCounts

    XCTAssertEqual(pointData.scale, expectedScale)
    XCTAssertEqual(pointData.positiveBuckets.scale, expectedScale)
    XCTAssertEqual(pointData.negativeBuckets.scale, expectedScale)
    XCTAssertEqual(pointData.zeroCount, 2)

    let positiveOffset = pointData.positiveBuckets.offset
    XCTAssertEqual(pointData.positiveBuckets.totalCount, 5)
    XCTAssertEqual(positiveCounts[valueToIndex(scale: expectedScale, value: 0.5) - positiveOffset], 1)
    XCTAssertEqual(positiveCounts[valueToIndex(scale: expectedScale, value: 1.0) - positiveOffset], 1)
    XCTAssertEqual(positiveCounts[valueToIndex(scale: expectedScale, value: 12.0) - positiveOffset], 2)
    XCTAssertEqual(positiveCounts[valueToIndex(scale: expectedScale, value: 15.213) - positiveOffset], 1)

    let negativeOffset = pointData.negativeBuckets.offset
    XCTAssertEqual(pointData.negativeBuckets.totalCount, 3)
    XCTAssertEqual(negativeCounts[valueToIndex(scale: expectedScale, value: 13.2) - negativeOffset], 1)
    XCTAssertEqual(negativeCounts[valueToIndex(scale: expectedScale, value: 2.01) - negativeOffset], 1)
    XCTAssertEqual(negativeCounts[valueToIndex(scale: expectedScale, value: 1.0) - negativeOffset], 1)
  }

  func testInvalidRecording() {
    let aggregator = DoubleBase2ExponentialHistogramAggregator(maxBuckets: 160, maxScale: 20, reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle() as! DoubleBase2ExponentialHistogramAggregator.Handle

    handle.doRecordDouble(value: Double.infinity)
    handle.doRecordDouble(value: Double.infinity * -1)
    handle.doRecordDouble(value: Double.nan)

    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1, attributes: [:], reset: false) as! ExponentialHistogramPointData
    XCTAssertNotNil(pointData)
    XCTAssertEqual(pointData.sum, 0)
    XCTAssertEqual(pointData.positiveBuckets.totalCount, 0)
    XCTAssertEqual(pointData.negativeBuckets.totalCount, 0)
    XCTAssertEqual(pointData.zeroCount, 0)
  }

  func testAggregateThenMaybeResetWithExemplars() {
    let aggregator = DoubleBase2ExponentialHistogramAggregator(maxBuckets: 160, maxScale: 20, reservoirSupplier: { self.reservoir })
    let attr: [String: AttributeValue] = ["test": .string("value")]

    let handle = aggregator.createHandle() as! DoubleBase2ExponentialHistogramAggregator.Handle
    handle.recordDouble(value: 0, attributes: attr)

    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1, attributes: [:], reset: true)
    XCTAssertNotNil(pointData)
    let exemplars = pointData.exemplars

    let exemplarWithAttr = exemplars.filter { return !$0.filteredAttributes.isEmpty }
    XCTAssertEqual(exemplarWithAttr.count, 1)
    XCTAssertEqual(exemplarWithAttr.first?.filteredAttributes, attr)
  }

  func testAggregateThenMaybeReset() {
    let aggregator = DoubleBase2ExponentialHistogramAggregator(maxBuckets: 160, maxScale: 20, reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle() as! DoubleBase2ExponentialHistogramAggregator.Handle

    handle.recordDouble(value: 5.0)

    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1, attributes: [:], reset: true) as! ExponentialHistogramPointData
    let positiveBuckets = pointData.positiveBuckets.bucketCounts
    XCTAssertNotNil(positiveBuckets)
    XCTAssertEqual(positiveBuckets, [Int64(1)])
  }

  func testDownScale() {
    let aggregator = DoubleBase2ExponentialHistogramAggregator(maxBuckets: 160, maxScale: 20, reservoirSupplier: { ExemplarReservoir() })
    let handle = aggregator.createHandle() as! DoubleBase2ExponentialHistogramAggregator.Handle

    handle.recordDouble(value: 0.5)
    handle.downScale(by: 20)

    handle.recordDouble(value: 1.0)
    handle.recordDouble(value: 2.0)
    handle.recordDouble(value: 4.0)
    handle.recordDouble(value: 16.0)

    let pointData = handle.aggregateThenMaybeReset(startEpochNano: 0, endEpochNano: 1, attributes: [:], reset: true) as! ExponentialHistogramPointData

    XCTAssertEqual(pointData.scale, 0)
    XCTAssertEqual(pointData.positiveBuckets.scale, 0)
    XCTAssertEqual(pointData.negativeBuckets.scale, 0)

    let buckets = pointData.positiveBuckets
    XCTAssertEqual(pointData.sum, 23.5)
    XCTAssertEqual(buckets.offset, -2)
    XCTAssertEqual(buckets.bucketCounts, [1, 1, 1, 1, 0, 1])
    XCTAssertEqual(buckets.totalCount, 5)
  }
}

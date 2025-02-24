/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class HistogramAggregatorTests: XCTestCase {
  public func testConstructedHistogramAggregator() {
    XCTAssertNoThrow(try HistogramAggregator(explicitBoundaries: [5, 10, 25]))
  }

  public func testUsesDefaultBoundariesWhenNotExplicit() {
    let aggregator = try! HistogramAggregator<Int>()
    let histogram = aggregator.toMetricData() as! HistogramData<Int>

    XCTAssertEqual([5, 10, 25, 50, 75, 100, 250, 500, 750, 1_000, 2_500, 5_000, 7_500,
                    10_000], histogram.buckets.boundaries)
  }

  public func testSortsBoundaries() {
    let aggregator = try! HistogramAggregator(explicitBoundaries: [100, 5, 10, 50, 25])
    let histogram = aggregator.toMetricData() as! HistogramData<Int>

    XCTAssertEqual([5, 10, 25, 50, 100], histogram.buckets.boundaries)
  }

  public func testUpdatesBucketsWithValue() {
    let aggregator = try! HistogramAggregator(explicitBoundaries: [100, 200])

    // Should start with 0 values
    var histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(0, histogram.count)

    // Should update the second bucket
    aggregator.update(value: 150)
    aggregator.checkpoint()
    histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(0, histogram.buckets.counts[0])
    XCTAssertEqual(1, histogram.buckets.counts[1])
    XCTAssertEqual(0, histogram.buckets.counts[2])

    // Should update the first bucket
    aggregator.update(value: 1)
    aggregator.checkpoint()
    histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(1, histogram.buckets.counts[0])
    XCTAssertEqual(0, histogram.buckets.counts[1])
    XCTAssertEqual(0, histogram.buckets.counts[2])

    // Should update the third bucket for out of boundary value
    aggregator.update(value: 1000)
    aggregator.checkpoint()
    histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(0, histogram.buckets.counts[0])
    XCTAssertEqual(0, histogram.buckets.counts[1])
    XCTAssertEqual(1, histogram.buckets.counts[2])

    // Should update the third bucket for boundary edge
    aggregator.update(value: 200)
    aggregator.checkpoint()
    histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(0, histogram.buckets.counts[0])
    XCTAssertEqual(0, histogram.buckets.counts[1])
    XCTAssertEqual(1, histogram.buckets.counts[2])
  }

  public func testUpdatesCountSumWithValue() {
    let aggregator = try! HistogramAggregator(explicitBoundaries: [100, 200])

    // Should start with 0 values
    var histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(0, histogram.count)

    // Updating 1 value
    aggregator.update(value: 150)
    aggregator.checkpoint()
    histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(1, histogram.count)
    XCTAssertEqual(150, histogram.sum)

    // Updating multiple values in different buckets
    aggregator.update(value: 50)
    aggregator.update(value: 100)
    aggregator.update(value: 150)
    aggregator.update(value: 200)
    aggregator.checkpoint()
    histogram = aggregator.toMetricData() as! HistogramData<Int>
    XCTAssertEqual(4, histogram.count)
    XCTAssertEqual(50 + 100 + 150 + 200, histogram.sum)
  }
}

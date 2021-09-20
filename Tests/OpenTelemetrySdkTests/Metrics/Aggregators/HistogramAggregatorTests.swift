/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class HistogramAggregatorTests: XCTestCase {
    public func testConstructedHistogramAggregator() {
        XCTAssertNoThrow(try HistogramAggregator(boundaries: [5, 10, 25]))
    }
    
    public func testThrowsWithNoBoundaries() {
        let boundaries = [Int]()
        XCTAssertThrowsError(try HistogramAggregator(boundaries: boundaries))
    }
    
    public func testSortsBoundaries() {
        let aggregator = try! HistogramAggregator(boundaries: [100, 5, 10, 50, 25])
        let histogram = aggregator.toMetricData() as! HistogramData<Int>
        
        XCTAssertEqual([5, 10, 25, 50, 100], histogram.buckets.boundaries)
    }
    
    public func testUpdatesBucketsWithValue() {
        let aggregator = try! HistogramAggregator(boundaries: [100, 200])
        
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
        let aggregator = try! HistogramAggregator(boundaries: [100, 200])
        
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

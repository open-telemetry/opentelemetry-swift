//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

public class AggregationsTests: XCTestCase {
    func testDropAggregation() {
        XCTAssert(Aggregations.drop() === DropAggregation.instance)
    }

    func testDefaultAggregation() {
        XCTAssert(Aggregations.defaultAggregation() === DefaultAggregation.instance)
    }

    func testSumAggregation() {
        XCTAssert(Aggregations.sum() === SumAggregation.instance)
    }

    func testLastValueAggregation() {
        XCTAssert(Aggregations.lastValue() === LastValueAggregation.instance)
    }

    func testExplicitBucketHistogramAggregation() {
        XCTAssert(Aggregations.explicitBucketHistogram() === ExplicitBucketHistogramAggregation.instance)
    }

    func testExplicitBucketHistogramAggregationWithBuckets() {
        let buckets = [0.0, 10.0, 20.0, 30.0]
        let aggregation = Aggregations.explicitBucketHistogram(buckets: buckets) as? ExplicitBucketHistogramAggregation
        XCTAssertEqual(aggregation?.bucketBoundaries, buckets)
    }

    func testBase2ExponentialBucketHistogram() {
        // TODO: write test case
    }

    func testBase2ExponentialBucketHistogramWithMaxBucketsAndMaxScale() {
        // TODO: write test case
    }
}

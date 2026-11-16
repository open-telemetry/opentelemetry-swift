//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class DoubleBase2ExponentialHistogramBucketsTests: XCTestCase {
  func testRecordValid() {
    let buckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)
    XCTAssertTrue(buckets.record(value: 1))
    XCTAssertTrue(buckets.record(value: 1))
    XCTAssertTrue(buckets.record(value: 1))
    XCTAssertEqual(buckets.totalCount, 3)
    XCTAssertEqual(buckets.bucketCounts, [3])
  }

  func testRecordZeroError() {
    let buckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)
    XCTAssertFalse(buckets.record(value: 0))
  }

  func testDownscaleValid() {
    let buckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)
    buckets.downscale(by: 20)
    buckets.record(value: 1)
    buckets.record(value: 2)
    buckets.record(value: 4)

    XCTAssertEqual(buckets.scale, 0)
    XCTAssertEqual(buckets.totalCount, 3)
    XCTAssertEqual(buckets.bucketCounts, [1, 1, 1])
    XCTAssertEqual(buckets.offset, -1)
  }

  func testClear() {
    let buckets = DoubleBase2ExponentialHistogramBuckets(scale: 20, maxBuckets: 160)
    XCTAssertTrue(buckets.record(value: 1))
    XCTAssertTrue(buckets.record(value: 1))
    XCTAssertEqual(buckets.totalCount, 2)
    XCTAssertEqual(buckets.bucketCounts, [2])

    buckets.clear(scale: 10)
    XCTAssertEqual(buckets.totalCount, 0)
    XCTAssertEqual(buckets.offset, 0)
    XCTAssertEqual(buckets.bucketCounts, [])
  }
}

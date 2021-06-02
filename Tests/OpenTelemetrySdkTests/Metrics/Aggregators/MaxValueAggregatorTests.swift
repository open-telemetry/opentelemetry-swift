/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class MaxValueAggregatorTests : XCTestCase {
    public func testAsyncSafety() {
        let agg = MaxValueAggregator<Int>()
        var sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 0)

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            for i in 0 ..< 10000 {
                agg.update(value: i)
            }
        }

        agg.update(value: 10001)

        agg.checkpoint()
        sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 10001)
    }

    public func testMaxAggPeriod() {
        let agg = MaxValueAggregator<Int>()
        var sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 0)

        agg.update(value: 100)
        agg.checkpoint()

        sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 100)

        agg.update(value: 88)
        agg.checkpoint()

        sum = agg.toMetricData() as! SumData<Int>

        XCTAssertEqual(sum.sum, 88)

    }
}
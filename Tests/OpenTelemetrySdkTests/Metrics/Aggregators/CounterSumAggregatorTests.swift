/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class MeterFactoryBaseTests: XCTestCase {
    public func testAggregatesCorrectlyWhenMultipleThreadsUpdatesInt() {
        // create an aggregator
        let aggregator = CounterSumAggregator<Int>()
        var sum = aggregator.toMetricData() as! SumData<Int>

        // we start with 0.
        XCTAssertEqual(sum.sum, 0)

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            for _ in 0 ..< 10000 {
                aggregator.update(value: 10)
            }
        }

        // check point.
        aggregator.checkpoint()
        sum = aggregator.toMetricData() as! SumData<Int>

        // 100000 times 10 by each thread
        XCTAssertEqual(sum.sum, 1000000)
    }
    
    public func testAggregatesCorrectlyWhenMultipleThreadsUpdatesDouble() {
        // create an aggregator
        let aggregator = CounterSumAggregator<Double>()
        var sum = aggregator.toMetricData() as! SumData<Double>

        // we start with 0.0
        XCTAssertEqual(sum.sum, 0.0)

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            for _ in 0 ..< 10000 {
                aggregator.update(value: 10.5)
            }
        }

        // check point.
        aggregator.checkpoint()
        sum = aggregator.toMetricData() as! SumData<Double>

        // 100000 times 10.5 by each thread
        XCTAssertEqual(sum.sum, 1050000)
    }
}

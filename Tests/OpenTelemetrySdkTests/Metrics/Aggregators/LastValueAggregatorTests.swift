/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class LastValueAggregatorTests: XCTestCase {
  public func testAggregatesCorrectlyInt() {
    // create an aggregator
    let aggregator = LastValueAggregator<Int>()
    var sum = aggregator.toMetricData() as! SumData<Int>

    // we start with 0.
    XCTAssertEqual(0, sum.sum)

    aggregator.update(value: 10)
    aggregator.update(value: 20)
    aggregator.update(value: 30)
    aggregator.update(value: 40)

    aggregator.checkpoint()
    sum = aggregator.toMetricData() as! SumData<Int>
    XCTAssertEqual(40, sum.sum)
  }

  public func testAggregatesCorrectlyDouble() {
    // create an aggregator
    let aggregator = LastValueAggregator<Double>()
    var sum = aggregator.toMetricData() as! SumData<Double>

    // we start with 0.
    XCTAssertEqual(0.0, sum.sum)

    aggregator.update(value: 40.5)
    aggregator.update(value: 30.5)
    aggregator.update(value: 20.5)
    aggregator.update(value: 10.5)

    aggregator.checkpoint()
    sum = aggregator.toMetricData() as! SumData<Double>
    XCTAssertEqual(10.5, sum.sum)
  }
}

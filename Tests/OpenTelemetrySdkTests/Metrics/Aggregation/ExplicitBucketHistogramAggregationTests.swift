//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class ExplicitBucketHistogramAggregationTests: XCTestCase {
  func testCreateAggregator() {
    let boundaries: [Double] = [0, 10, 20, 30, 40]
    let aggregation = ExplicitBucketHistogramAggregation(bucketBoundaries: boundaries)
    let descriptor = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .histogram, valueType: .double)
    let exemplarFilter = AlwaysOnFilter()

    let aggregator = aggregation.createAggregator(descriptor: descriptor, exemplarFilter: exemplarFilter) as! DoubleExplicitBucketHistogramAggregator

    XCTAssertNotNil(aggregator)
    XCTAssertEqual(aggregator.boundaries, boundaries)
  }

  func testIsCompatible() {
    let aggregation = ExplicitBucketHistogramAggregation(bucketBoundaries: [0, 10, 20, 30, 40])

    let compatibleDescriptor1 = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .counter, valueType: .double)
    let compatibleDescriptor2 = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .histogram, valueType: .double)
    let incompatibleDescriptor = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .observableGauge, valueType: .double)

    XCTAssertTrue(aggregation.isCompatible(with: compatibleDescriptor1))
    XCTAssertTrue(aggregation.isCompatible(with: compatibleDescriptor2))
    XCTAssertFalse(aggregation.isCompatible(with: incompatibleDescriptor))
  }
}

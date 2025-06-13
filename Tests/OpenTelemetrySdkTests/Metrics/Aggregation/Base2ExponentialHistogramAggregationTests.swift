//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class Base2ExponentialHistogramAggregationTests: XCTestCase {
  func testInit() {
    XCTAssertNotNil(Base2ExponentialHistogramAggregation.instance)
    XCTAssertNotNil(Base2ExponentialHistogramAggregation(maxBuckets: 160, maxScale: 20))
  }

  func testInvalidConfigsDefault() {
    // Current init doesn't throw exception for out of bounds config values; instead it falls back to the default values in iOS

    let invalidMaxBuckets = Base2ExponentialHistogramAggregation(maxBuckets: 0, maxScale: 20)
    let invalidMaxScaleUpper = Base2ExponentialHistogramAggregation(maxBuckets: 2, maxScale: 21)
    let invalidMaxScaleLower = Base2ExponentialHistogramAggregation(maxBuckets: 2, maxScale: -11)

    XCTAssertEqual(invalidMaxBuckets.maxBuckets, 160)
    XCTAssertEqual(invalidMaxScaleUpper.maxScale, 20)
    XCTAssertEqual(invalidMaxScaleLower.maxScale, 20)
  }

  func testCreateAggregator() throws {
    let aggregation = Base2ExponentialHistogramAggregation(maxBuckets: 160, maxScale: 20)
    let descriptor = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .histogram, valueType: .double)
    let exemplarFilter = AlwaysOnFilter()
    let aggregator = try XCTUnwrap(aggregation.createAggregator(descriptor: descriptor, exemplarFilter: exemplarFilter) as? DoubleBase2ExponentialHistogramAggregator)

    XCTAssertNotNil(aggregator)
  }

  func testIsCompatible() {
    let aggregation = Base2ExponentialHistogramAggregation(maxBuckets: 160, maxScale: 20)

    let compatibleDescriptor1 = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .counter, valueType: .double)
    let compatibleDescriptor2 = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .histogram, valueType: .double)
    let incompatibleDescriptor1 = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .observableGauge, valueType: .double)
    let incompatibleDescriptor2 = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .observableCounter, valueType: .double)
    let incompatibleDescriptor3 = InstrumentDescriptor(name: "test", description: "test", unit: "unit", type: .observableUpDownCounter, valueType: .double)

    XCTAssertTrue(aggregation.isCompatible(with: compatibleDescriptor1))
    XCTAssertTrue(aggregation.isCompatible(with: compatibleDescriptor2))
    XCTAssertFalse(aggregation.isCompatible(with: incompatibleDescriptor1))
    XCTAssertFalse(aggregation.isCompatible(with: incompatibleDescriptor2))
    XCTAssertFalse(aggregation.isCompatible(with: incompatibleDescriptor3))
  }
}

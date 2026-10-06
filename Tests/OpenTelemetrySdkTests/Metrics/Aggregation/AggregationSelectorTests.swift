//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

public class AggregationSelectorTests: XCTestCase {
  func testGetDefaultAggregation() {
    let selector = AggregationSelector()
    let instrumentType = InstrumentType.counter
    XCTAssert(selector.getDefaultAggregation(for: instrumentType) === Aggregations.defaultAggregation())
  }

  func testDefaultAggregationResolver() {
    let resolver = AggregationSelector.defaultSelector()
    let instrumentType = InstrumentType.histogram
    XCTAssert(resolver(instrumentType) === Aggregations.defaultAggregation())
  }

  func testAggregationResolverForInstrumentType() {
    let selector = AggregationSelector()
    let instrumentType = InstrumentType.observableUpDownCounter
    let aggregation = Aggregations.sum()
    let resolver = selector.with(instrumentType: instrumentType, aggregation: aggregation)
    XCTAssert(resolver(instrumentType) === aggregation)
  }

  func testAggregationResolverForDifferentInstrumentType() {
    let selector = AggregationSelector()
    let instrumentType = InstrumentType.observableCounter
    let aggregation = Aggregations.sum()
    let resolver = selector.with(instrumentType: instrumentType, aggregation: aggregation)
    let instrumentType2 = InstrumentType.histogram
    XCTAssert(resolver(instrumentType2) === Aggregations.defaultAggregation())
  }
}

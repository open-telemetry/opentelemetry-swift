//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ExplicitBucketHistogramAggregation: Aggregation {
  public private(set) static var DEFAULT_BOUNDARIES: [Double] = [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1_000, 2_500, 5_000, 7_500]
  public private(set) static var instance = ExplicitBucketHistogramAggregation(bucketBoundaries: DEFAULT_BOUNDARIES)

  let bucketBoundaries: [Double]

  public init(bucketBoundaries: [Double]) {
    self.bucketBoundaries = bucketBoundaries
  }

  public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> any Aggregator {
    DoubleExplicitBucketHistogramAggregator(boundaries: bucketBoundaries) {
      FilteredExemplarReservoir(filter: exemplarFilter, reservoir: HistogramExemplarReservoir(clock: MillisClock(), boundaries: self.bucketBoundaries)) // TODO: inject correct clock
    }
  }

  public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
    switch descriptor.type {
    case .counter, .histogram:
      return true
    default:
      return false
    }
  }
}

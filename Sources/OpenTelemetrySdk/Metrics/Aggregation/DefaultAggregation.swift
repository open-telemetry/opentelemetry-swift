//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class DefaultAggregation: Aggregation {
  public private(set) static var instance = DefaultAggregation()

  public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> any Aggregator {
    resolve(for: descriptor).createAggregator(descriptor: descriptor, exemplarFilter: exemplarFilter)
  }

  public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
    resolve(for: descriptor).isCompatible(with: descriptor)
  }

  private func resolve(for instrument: InstrumentDescriptor) -> Aggregation {
    switch instrument.type {
    case .counter, .upDownCounter, .observableCounter, .observableUpDownCounter:
      return SumAggregation.instance
    case .histogram:
      // Use advisory bucket boundaries if available, otherwise use default
      if let advisoryBoundaries = instrument.explicitBucketBoundariesAdvice {
        return ExplicitBucketHistogramAggregation(bucketBoundaries: advisoryBoundaries)
      } else {
        return ExplicitBucketHistogramAggregation.instance
      }
    case .observableGauge, .gauge:
      return LastValueAggregation.instance
    }
  }
}

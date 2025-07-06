//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class Base2ExponentialHistogramAggregation: Aggregation {
  private static let defaultMaxBuckets = 160
  private static let defaultMaxScale = 20

  public private(set) static var instance = Base2ExponentialHistogramAggregation(maxBuckets: defaultMaxBuckets, maxScale: defaultMaxScale)

  let maxBuckets: Int
  let maxScale: Int

  public init(maxBuckets: Int, maxScale: Int) {
    self.maxScale = maxScale <= 20 && maxScale >= -10 ? maxScale : Self.defaultMaxScale
    self.maxBuckets = maxBuckets >= 2 ? maxBuckets : Self.defaultMaxBuckets
  }

  public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> Aggregator {
    DoubleBase2ExponentialHistogramAggregator(maxBuckets: maxBuckets, maxScale: maxScale) {
      FilteredExemplarReservoir(filter: exemplarFilter, reservoir: LongToDoubleExemplarReservoir(reservoir: RandomFixedSizedExemplarReservoir.createDouble(clock: MillisClock(), size: 2)))
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

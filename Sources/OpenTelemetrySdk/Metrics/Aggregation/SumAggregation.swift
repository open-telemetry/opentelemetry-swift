//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class SumAggregation: Aggregation {
  public private(set) static var instance = SumAggregation()

  public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
    switch descriptor.type {
    case .counter, .observableUpDownCounter, .observableCounter, .upDownCounter, .histogram:
      return true
    default:
      return false
    }
  }

  public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> any Aggregator {
    switch descriptor.valueType {
    case .long:
      return LongSumAggregator(descriptor: descriptor, reservoirSupplier: {
        FilteredExemplarReservoir(filter: exemplarFilter,
                                  reservoir: RandomFixedSizedExemplarReservoir.createLong(clock: MillisClock(), size: 2))
      })
    case .double:
      return DoubleSumAggregator(instrumentDescriptor: descriptor, reservoirSupplier: {
        FilteredExemplarReservoir(filter: exemplarFilter,
                                  reservoir: RandomFixedSizedExemplarReservoir.createDouble(clock: MillisClock(), size: 2))

      })
    }
  }
}

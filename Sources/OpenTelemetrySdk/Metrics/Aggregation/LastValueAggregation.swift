//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LastValueAggregation: Aggregation {
  public private(set) static var instance = LastValueAggregation()

  public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> Aggregator {
    switch descriptor.valueType {
    case .double:
      return DoubleLastValueAggregator(reservoirSupplier: {
        FilteredExemplarReservoir(filter: exemplarFilter, reservoir: RandomFixedSizedExemplarReservoir.createDouble(clock: MillisClock(), size: 2))
      })
    case .long:
      return LongLastValueAggregator(reservoirSupplier: {
        FilteredExemplarReservoir(filter: exemplarFilter, reservoir: RandomFixedSizedExemplarReservoir.createLong(clock: MillisClock(), size: 2))
      })
    }
  }

  public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
    return descriptor.type == .observableGauge
  }
}

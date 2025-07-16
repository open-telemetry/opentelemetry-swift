//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DropAggregation: Aggregation {
  public private(set) static var instance = DropAggregation()

  public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> any Aggregator {
    return DropAggregator()
  }

  public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
    true
  }
}

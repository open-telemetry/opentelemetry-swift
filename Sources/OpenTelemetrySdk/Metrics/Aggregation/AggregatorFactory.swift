//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol Aggregation: AnyObject, Sendable {
  func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> Aggregator
  func isCompatible(with descriptor: InstrumentDescriptor) -> Bool
}

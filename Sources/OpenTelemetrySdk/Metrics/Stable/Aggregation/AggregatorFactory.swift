//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public protocol AggregatorFactory {
    func createAggregator(descriptor : InstrumentDescriptor, exemplarFilter : ExemplarFilter) -> any StableAggregator
    func isCompatible(with descriptor: InstrumentDescriptor) -> Bool
}

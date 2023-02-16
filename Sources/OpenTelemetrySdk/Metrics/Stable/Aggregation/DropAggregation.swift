//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


public class DropAggregation : Aggregation, AggregatorFactory {

    
    public private(set) static var instance = DropAggregation()
    
    public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter:  ExemplarFilter) -> Aggregator<T,U> {
        Aggregator.drop()
    }

    public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
        true
    }

    
}

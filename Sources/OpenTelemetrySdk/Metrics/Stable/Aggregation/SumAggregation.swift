//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class SumAggregation : Aggregation, AggregatorFactory {
   
    
    public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
        switch (descriptor.type) {
        case .counter,.observableUpDownCounter,.observableCounter,.upDownCounter,.histogram:
            return true
        default:
            return false
        }
    }
    
    public private(set) static var instance = SumAggregation()
    
    public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> any StableAggregator {
        switch(descriptor.valueType) {
        case .long:
            return
        case .double:
            return 
        }
    }
}

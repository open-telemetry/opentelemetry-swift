//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public class DefaultAggregation : Aggregation, AggregatorFactory {
    
    public func isCompatible(with descriptor: InstrumentDescriptor) {
        
    }
    
    private static let instance = defaultAggregation()
    
    public static func get() -> Aggregation {
        return instance
    }
    
    
    
}

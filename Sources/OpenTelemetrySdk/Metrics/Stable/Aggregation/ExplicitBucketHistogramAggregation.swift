//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class ExplicitBucketHistogramAggregation : Aggregation, AggregatorFactory {
    public private(set) static var DEFAULT_BOUNDRIES : [Double] = [0,5,10,25,50,75,100,250,500,750,1_000,2_500,5_000,7_500]
    public private(set) static var instance = ExplicitBucketHistogramAggregation(bucketBoundries: DEFAULT_BOUNDRIES)
    
    
    private let bucketBoundries : [Double]
    
    init(bucketBoundries : [Double]) {
        self.bucketBoundries = bucketBoundries
    }
    
    public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> any StableAggregator {
        
    }
    
    public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
        switch(descriptor.type) {
        case .counter, .histogram:
            return true
        default:
          return false
        }
    }
}

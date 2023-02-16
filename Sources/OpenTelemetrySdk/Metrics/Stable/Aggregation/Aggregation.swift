//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


typealias DefaultAggregationSelector = (InstrumentType) -> Aggregation

public class Aggregation {
    static func drop() -> Aggregation {
        
    }
    
    static func defaultAggregation() -> Aggregation {
        
    }
    
    static func sum() -> Aggregation {
        
    }
    
    static func lastValue() -> Aggregation {
        
    }
    
    static func explicitBucketHistogram() {
        
    }
    
    static func explicitBucketHistogram(buckets: [Double]) {
        
    }
    
    static func base2ExponentialBucketHistogram() {
        
    }
    
    static func base2ExponentialBucketHistogram(int maxBuckets, int maxScale) {
        
    }
}

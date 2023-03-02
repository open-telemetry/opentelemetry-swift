//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public protocol Aggregation : AggregatorFactory {}

public class Aggregations {
    static func drop() -> Aggregation {
        DropAggregation.instance
    }
    
    static func defaultAggregation() -> Aggregation {
        DefaultAggregation.instance
    }
    
    static func sum() -> Aggregation {
        
    }
    
    static func lastValue() -> Aggregation {
        
    }
    
    static func explicitBucketHistogram() -> Aggregation {
        ExplicitBucketHistogramAggregation.instance
    }
    
    static func explicitBucketHistogram(buckets: [Double]) {
        
    }
    
    static func base2ExponentialBucketHistogram() {
        
    }
    
    static func base2ExponentialBucketHistogram(maxBuckets: Int, maxScale: Int) {
        
    }
}

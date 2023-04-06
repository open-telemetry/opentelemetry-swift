//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public protocol Aggregation : AggregatorFactory {}

public class Aggregations {
    public static func drop() -> Aggregation {
        DropAggregation.instance
    }
    
    public static func defaultAggregation() -> Aggregation {
        DefaultAggregation.instance
    }
    
    public static func sum() -> Aggregation {
        SumAggregation.instance
    }
    
    public static func lastValue() -> Aggregation {
        LastValueAggregation.instance
    }
    
    public static func explicitBucketHistogram() -> Aggregation {
        ExplicitBucketHistogramAggregation.instance
    }
    
    public static func explicitBucketHistogram(buckets: [Double]) -> Aggregation {
        ExplicitBucketHistogramAggregation(bucketBoundries:  buckets)
    }
    
    static func base2ExponentialBucketHistogram() {
        // todo
    }
    
    static func base2ExponentialBucketHistogram(maxBuckets: Int, maxScale: Int) {
        // todo
    }
}

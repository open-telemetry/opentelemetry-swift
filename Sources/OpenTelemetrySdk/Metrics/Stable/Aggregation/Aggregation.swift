//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public enum Aggregations {
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
        ExplicitBucketHistogramAggregation(bucketBoundaries: buckets)
    }
    
    static func base2ExponentialBucketHistogram() -> Aggregation {
        Base2ExponentialHistogramAggregation.instance
    }
    
    static func base2ExponentialBucketHistogram(maxBuckets: Int, maxScale: Int) -> Aggregation {
        Base2ExponentialHistogramAggregation(maxBuckets: maxBuckets, maxScale: maxScale)
    }
}

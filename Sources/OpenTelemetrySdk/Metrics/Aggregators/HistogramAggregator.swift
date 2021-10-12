/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Aggregator which calculates histogram (bucket distribution, sum, count) from measures.
public class HistogramAggregator<T: SignedNumeric & Comparable>: Aggregator<T> {
    fileprivate var histogram: Histogram<T>
    fileprivate var pointCheck: Histogram<T>
    fileprivate var boundaries: Array<T>
    
    private let lock = Lock()
    private let defaultBoundaries: Array<T> = [5, 10, 25, 50, 75, 100, 250, 500, 750, 1_000, 2_500, 5_000, 7_500,
                                            10_000]
    
    public init(explicitBoundaries: Array<T>? = nil) throws {
        if let explicitBoundaries = explicitBoundaries, explicitBoundaries.count > 0 {
          // we need to an ordered set to be able to correctly compute count for each
          // boundary since we'll iterate on each in order.
          self.boundaries = explicitBoundaries.sorted { $0 < $1 }
        } else {
          self.boundaries = defaultBoundaries
        }
        
        self.histogram = Histogram<T>(boundaries: self.boundaries)
        self.pointCheck = Histogram<T>(boundaries: self.boundaries)
    }
    
    override public func update(value: T) {
        lock.withLockVoid {
            self.histogram.count += 1
            self.histogram.sum += value
            
            for i in 0..<self.boundaries.count {
                if value < self.boundaries[i] {
                    self.histogram.buckets.counts[i] += 1
                    return
                }
            }
            // value is above all observed boundaries
            self.histogram.buckets.counts[self.boundaries.count] += 1
        }
    }
    
    override public func checkpoint() {
        lock.withLockVoid {
            super.checkpoint()
            pointCheck = histogram
            histogram = Histogram<T>(boundaries: self.boundaries)
        }
    }
    
    public override func toMetricData() -> MetricData {
        return HistogramData<T>(startTimestamp: lastStart,
                                timestamp: lastEnd,
                                buckets: pointCheck.buckets,
                                count: pointCheck.count,
                                sum: pointCheck.sum)
    }
    
    public override func getAggregationType() -> AggregationType {
        if T.self == Double.Type.self {
            return .doubleHistogram
        } else {
            return .intHistogram
        }
    }
}

private struct Histogram<T> where T: SignedNumeric {
    /*
     * Buckets are implemented using two different arrays:
     *  - boundaries: contains every finite bucket boundary, which are inclusive lower bounds
     *  - counts: contains event counts for each bucket
     *
     * Note that we'll always have n+1 buckets, where n is the number of boundaries.
     * This is because we need to count events that are below the lowest boundary.
     *
     * Example: if we measure the values: [5, 30, 5, 40, 5, 15, 15, 15, 25]
     *  with the boundaries [ 10, 20, 30 ], we will have the following state:
     *
     * buckets: {
     *  boundaries: [10, 20, 30],
     *  counts: [3, 3, 1, 2],
     * }
     */
    var buckets: (
        boundaries: Array<T>,
        counts: Array<Int>
    )
    var sum: T
    var count: Int
    
    init(boundaries: Array<T>) {
        sum = 0
        count = 0
        buckets = (
            boundaries: boundaries,
            counts: Array(repeating: 0, count: boundaries.count + 1)
        )
    }
}

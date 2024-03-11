//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ExponentialHistogramPointData: PointData {

    public var scale: Int
    public var sum: Double
    public var count: Int
    public var zeroCount: Int64
    public var hasMin: Bool
    public var hasMax: Bool
    public var min: Double
    public var max: Double
    public var positiveBuckets: ExponentialHistogramBuckets
    public var negativeBuckets: ExponentialHistogramBuckets

    public init(scale: Int, sum: Double, zeroCount: Int64, hasMin: Bool, hasMax: Bool, min: Double, max: Double, positiveBuckets: ExponentialHistogramBuckets, negativeBuckets: ExponentialHistogramBuckets, startEpochNanos: UInt64, epochNanos: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData]) {
        
        self.scale = scale
        self.sum = sum
        self.zeroCount = zeroCount
        self.hasMin = hasMin
        self.hasMax = hasMax
        self.min = min
        self.max = max
        self.positiveBuckets = positiveBuckets
        self.negativeBuckets = negativeBuckets

        self.count = Int(zeroCount) + positiveBuckets.totalCount + negativeBuckets.totalCount

        super.init(startEpochNanos: startEpochNanos, endEpochNanos: epochNanos, attributes: attributes, exemplars: exemplars)
    }
}

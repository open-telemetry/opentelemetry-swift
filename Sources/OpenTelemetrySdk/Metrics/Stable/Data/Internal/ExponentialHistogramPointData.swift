////
//// Copyright The OpenTelemetry Authors
//// SPDX-License-Identifier: Apache-2.0
////
//
// import Foundation
// import OpenTelemetryApi
//
// public class ImmutableExponentialHistogramPointData : AnyPointData, ExponentialHistogramPointData {
//    public var scale: Int
//
//    public var sum: Double
//
//    public var count: Int
//
//    public var zeroCount: Int
//
//    public var hasMin: Bool
//
//    public var hasMax: Bool
//
//    public var max: Double
//
//    public var positiveBuckets: ExponentialHistogramBuckets
//
//    public var negativeBuckets: ExponentialHistogramBuckets
//
//    public init(scale: Int, sum: Double, zeroCount: Int, hasMin: Bool, hasMax: Bool, max: Double, positiveBuckets: ExponentialHistogramBuckets, negativeBuckets: ExponentialHistogramBuckets, startEpochNanos: UInt64, epochNanos: UInt64, attributes: [String: AttributeValue], exemplars: [AnyDoubleExemplarData]) {
//        self.scale = scale
//        self.sum = sum
//        self.zeroCount = zeroCount
//        self.hasMin = hasMin
//        self.hasMax = hasMax
//        self.max = max
//        self.positiveBuckets = positiveBuckets
//        self.negativeBuckets = negativeBuckets
//
//        self.count = zeroCount + positiveBuckets.totalCount + negativeBuckets.totalCount
//
//        super.init(startEpochNanos: startEpochNanos, endEpochNanos: epochNanos, attributes: attributes, exemplars: exemplars)
//
//    }
//
//
//
//
// }

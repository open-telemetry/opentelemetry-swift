////
//// Copyright The OpenTelemetry Authors
//// SPDX-License-Identifier: Apache-2.0
//// 
//
//import Foundation
//import OpenTelemetryApi
//
//public class Base2ExponentialBucketHistogramAggregation : Aggregation, AggregatorFactory {
//    private static let defaultMaxBuckets = 160
//    private static let defaultMaxScale = 20
//    
//    public private(set) static var instance = Base2ExponentialBucketHistogramAggregation(maxBuckets: defaultMaxBuckets, maxScale: defaultMaxScale)
//    
//    
//    private let maxBuckets : Int
//    private let maxScale : Int
//    
//    public init(maxBuckets : Int, maxScale : Int) {
//        
//        self.maxScale = maxScale <= 20 && maxScale >= -10 ? maxScale : Self.defaultMaxScale
//        self.maxBuckets = maxBuckets > 0 ? maxBuckets : Self.defaultMaxScale
//    }
//    
//    public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> StableAggregator {
//        <#code#>
//    }
//    
//    public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
//        switch descriptor.type {
//        case .counter, .histogram:
//            return true
//        default:
//            return false
//        }
//    }
//
//    
//    
//}

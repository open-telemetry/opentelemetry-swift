//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public protocol LongPointData : AnyPointData {
    var value : Int { get }
}

public protocol DoublePointData : AnyPointData {
    var value : Double { get }
}

public protocol SummaryPointData : AnyPointData {
    var count : UInt64 { get }
    var sum : Double { get }
    var values : [ValueAtQuantile] { get }
}


public protocol HistogramPointDataProtocol : AnyPointData {
    var sum : Double { get }
    var count : UInt64 { get }
    var min : Double { get }
    var max : Double { get }
    var boundries : [Double] { get }
    var counts : [Int] { get }
    var hasMin : Bool { get }
    var hasMax : Bool { get }
}


//public protocol ExponentialHistogramPointData : AnyPointData {
//    var scale : Int { get }
//    var sum : Double { get }
//    var count : Int { get }
//    var zeroCount : Int { get }
//    var hasMin : Bool { get }
//    var hasMax : Bool { get }
//    var max :  Double { get }
//    var positiveBuckets : ExponentialHistogramBuckets { get }
//    var negativeBuckets : ExponentialHistogramBuckets { get }
//    
//}


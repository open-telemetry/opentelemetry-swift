//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol PointData {
    var startEpochNanos : UInt64 { get }
    var endEpochNanos : UInt64 { get }
    var attributes : [String: AttributeValue] { get }
    var exemplars : [ExemplarData] { get }
    
    static func -(left: Self, right: Self) -> Self
    
}

public class AnyPointData  : PointData {

    internal init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String : AttributeValue], exemplars: [ExemplarData]) {
        self.startEpochNanos = startEpochNanos
        self.endEpochNanos = endEpochNanos
        self.attributes = attributes
        self.exemplars = exemplars
    }
    
    public var startEpochNanos: UInt64
    
    public var endEpochNanos: UInt64
    
    public var attributes: [String : OpenTelemetryApi.AttributeValue]
    
    public var exemplars: [ExemplarData]
    
    public static func - (left: AnyPointData, right: AnyPointData) -> Self {
        return left as! Self
    }
    
}


//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol PointData {
    var startEpochNanos : Int { get }
    var endEpochNanos : Int { get }
    var attributes : [String: AttributeValue] { get }
    var exemplars : [ExemplarData] { get }
}

public class AnyPointData  : PointData {
    internal init(startEpochNanos: Int, endEpochNanos: Int, attributes: [String : AttributeValue], exemplars: [ExemplarData]) {
        self.startEpochNanos = startEpochNanos
        self.endEpochNanos = endEpochNanos
        self.attributes = attributes
        self.exemplars = exemplars
    }
    
    public var startEpochNanos: Int
    
    public var endEpochNanos: Int
    
    public var attributes: [String : OpenTelemetryApi.AttributeValue]
    
    public var exemplars: [ExemplarData]
    

    
    
}

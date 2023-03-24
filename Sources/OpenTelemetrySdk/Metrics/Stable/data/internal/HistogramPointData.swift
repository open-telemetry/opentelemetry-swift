//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class HistogramPointData : AnyPointData, HistogramPointDataProtocol {
    
    
    
    internal init(startEpochNanos : UInt64, endEpochNanos: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData], sum: Double, count: UInt64, min: Double, max: Double, boundries: [Double], counts: [Int], hasMin: Bool, hasMax: Bool) {
        self.sum = sum
        self.count = count
        self.min = min
        self.max = max
        self.boundries = boundries
        self.counts = counts
        self.hasMin = hasMin
        self.hasMax = hasMax
        super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: exemplars)
    }
    
    public var sum: Double
    
    public var count: UInt64

    public var min: Double
    
    public var max: Double
    
    public var boundries: [Double]
    
    public var counts: [Int]
        
    public var hasMin: Bool
    
    public var hasMax: Bool
    
    
}

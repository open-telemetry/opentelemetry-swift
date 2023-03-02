//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class HistogramPointData : AnyPointData, HistogramPointDataProtocol {
    
    
    internal init(startEpochNanos : Int, endEpochNanos: Int, attributes: [String: AttributeValue], exemplars: [ExemplarData], sum: Double, count: Int, min: Double, max: Double, boundries: [Double], counts: [Int], hasMin: Bool, hasMax: Bool) {
        super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: exemplars)
        self.sum = sum
        self.count = count
        self.min = min
        self.max = max
        self.boundries = boundries
        self.counts = counts
        self.exemplars = exemplars
        self.hasMin = hasMin
        self.hasMax = hasMax
    }
    
    public var sum: Double
    
    public var count: Int
    
    public var min: Double
    
    public var max: Double
    
    public var boundries: [Double]
    
    public var counts: [Int]
        
    public var hasMin: Bool
    
    public var hasMax: Bool
    
    
}

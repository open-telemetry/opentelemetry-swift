//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class ImmutableSummaryPointData : AnyPointData, SummaryPointData {
    public var count: UInt64
        
    public var sum: Double
    
    public var values: [ValueAtQuantile]
    
    
    init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String : AttributeValue], count: UInt64, sum: Double, percentileValues: [ValueAtQuantile]) {
        self.count = count
        self.sum = sum
        self.values = percentileValues
        super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: [ExemplarData]())
    }
}

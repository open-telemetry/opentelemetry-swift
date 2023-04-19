//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongPointData: PointData {
    public var value: Int
    
    internal init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String : AttributeValue], exemplars: [ExemplarData], value: Int) {
        self.value = value
        super.init(startEpochNanos: startEpochNanos, endEpochNanos: endEpochNanos, attributes: attributes, exemplars: exemplars)
        
    }
    
    static func -(left : LongPointData, right: LongPointData) -> Self {
        return LongPointData(startEpochNanos: left.startEpochNanos, endEpochNanos: left.endEpochNanos, attributes: left.attributes, exemplars: left.exemplars, value: left.value - right.value) as! Self
    }
    
}



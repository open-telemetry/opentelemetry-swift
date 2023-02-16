//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class AggregatorHandle {

    
    let exemplarReservoir : any ExemplarReservoirProtocol
 
    internal init(exemplarReservoir: any ExemplarReservoirProtocol) {
        self.exemplarReservoir = exemplarReservoir
    }
    
    public func aggregateThenMaybeReset(startEpochNano: Int, endEpochNano: Int, attributes : [String: AttributeValue], reset: Bool) -> PointData {
        fatalError("required to subclass")
    }
    
    
    
    public func recordLong(value: Int, attributes: [String: AttributeValue]) {
        exemplarReservoir.offerLongMeasurement(value: value, attributes: attributes)
            recordLong(value: value)
    }
    
    public func recordLong(value: Int) {
        doRecordLong(value: value)
    }
    
    internal func doRecordLong(value: Int) {
        // noop
    }
    
    public func recordDouble(value: Double, attributes: [String: AttributeValue]) {
        exemplarReservoir.offerDoubleMeasurement(value: value, attributes: attributes)
    }
    
    public func recordDouble(value: Double) {
        doRecordDouble(value: value)
    }
    
    internal func doRecordDouble(value: Double) {
        // noop
    }
    
    
}

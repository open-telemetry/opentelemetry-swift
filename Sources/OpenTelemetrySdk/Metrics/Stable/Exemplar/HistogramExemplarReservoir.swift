//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class HistogramExemplarReservoir : FixedSizedExemplarReservoir {
    init(clock: Clock, boundries : [Double]) {
        // unsafeBitCast(ReservoirCell.getAndResetDouble, to: ((ReservoirCell, [String: AttributeValue]) -> ImmutableDoubleExemplarData).self)
        super.init(clock: clock, size: boundries.count + 1, reservoirCellSelector: HistogramCellSelector(boundries: boundries), mapAndResetCell: unsafeBitCast(ReservoirCell.getAndResetDouble, to: ((ReservoirCell, [String: AttributeValue])-> ImmutableDoubleExemplarData).self))
    }
    
    override public func offerLongMeasurement(value: Int, attributes: [String : AttributeValue]) {
        super.offerDoubleMeasurement(value: Double(value), attributes: attributes)
    }
    
    class HistogramCellSelector : ReservoirCellSelector {
        private var boundries : [Double]
        
        init(boundries: [Double]) { 
            self.boundries = boundries
        }
        
        func reservoirCellIndex(for cells: [ReservoirCell], value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) -> Int {
            reservoirCellIndex(for: cells, value: Double(value), attributes: attributes)
        }
        
        func reservoirCellIndex(for cells: [ReservoirCell], value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) -> Int {
            if let index = boundries.firstIndex(where: { boundry in
                value <= boundry
            }) {
                return index
            }
            return boundries.count
        }
        
        func reset() {
            // noop
        }
        
 
        

    }

}




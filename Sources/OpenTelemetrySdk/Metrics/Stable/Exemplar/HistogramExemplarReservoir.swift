//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class HistogramExemplarReservoir : FixedSizedExemplarReservoir {
    init(clock: Clock, boundries : [Double]) {
        super.init(clock: clock, size: boundries.count + 1, reservoirCellSelector: HistogramCellSelector(boundries: boundries), mapAndResetCell: { cell, attributes in
            return cell.getAndResetDouble(pointAttributes: attributes)
        })
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




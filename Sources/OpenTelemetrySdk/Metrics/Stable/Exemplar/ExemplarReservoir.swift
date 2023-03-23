//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol ExemplarReservoir {
    func offerDoubleMeasurement(value: Double, attributes: [String: AttributeValue])
    func offerLongMeasurement(value: Int, attributes: [String: AttributeValue])
    func collectAndReset(attribute: [String: AttributeValue]) -> [ExemplarData]
}

public class AnyExemplarReservoir : ExemplarReservoir {
   
    public func collectAndReset(attribute: [String : AttributeValue]) -> [ExemplarData] {
        return [AnyExemplarData]()
    }
    
    
    public func offerDoubleMeasurement(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        
    }
    
    public func offerLongMeasurement(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        
    }
    
    
}


public class NoopExemplarReservoir : AnyExemplarReservoir {
    public override func offerDoubleMeasurement(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        // noop
    }
    
    public override func offerLongMeasurement(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        // noop
    }
    
    public override func collectAndReset(attribute: [String : AttributeValue]) -> [ExemplarData] {
        return [ExemplarData]()
    }
    
    
}

public class ExemplarReservoirCollection {
    
    static func doubleNoSamples() -> AnyExemplarReservoir {
        return NoopExemplarReservoir()
    }
    
    static func longNoSamples() -> AnyExemplarReservoir {
        return NoopExemplarReservoir()
    }

    
    
}


public class FixedSizedExemplarReservoir : AnyExemplarReservoir {
    var storage : [ReservoirCell]
    let reservoirCellSelector : ReservoirCellSelector
    let mapAndResetCell : (ReservoirCell, [String:AttributeValue]) ->  ExemplarData?
    var hasMeasurements = false
    
    init(clock: Clock, size: Int, reservoirCellSelector: ReservoirCellSelector, mapAndResetCell: @escaping (ReservoirCell, [String : AttributeValue]) -> ExemplarData?) {
        storage = [ReservoirCell]()
        self.reservoirCellSelector = reservoirCellSelector
        self.mapAndResetCell = mapAndResetCell
        
        for _ in 0...size {
            storage.append(ReservoirCell(clock:clock))
        }
    }
    
    override public func offerLongMeasurement(value: Int, attributes: [String : AttributeValue]) {
        let bucketIndex = reservoirCellSelector.reservoirCellIndex(for: storage, value: value, attributes: attributes)
        
        if bucketIndex != -1 {
            storage[bucketIndex].recordLongValue(value: value, attributes: attributes)
            hasMeasurements = true
        }
    }
    
    override public func offerDoubleMeasurement(value: Double, attributes: [String : AttributeValue]) {
        let bucketIndex = reservoirCellSelector.reservoirCellIndex(for: storage, value: value, attributes: attributes)
        
        if bucketIndex != -1 {
            storage[bucketIndex].recordDoubleValue(value: value, attributes: attributes)
            hasMeasurements = true
        }
    }
    
    override public func collectAndReset(attribute: [String : AttributeValue]) -> [ExemplarData] {
       var results = [ExemplarData]()
        if !hasMeasurements {
            return results
        }
        for cell in storage {
            if let result = mapAndResetCell(cell, attribute) {
                results.append(result)
            }
        }
        reservoirCellSelector.reset()
        hasMeasurements = false
        return results
    }
    
}

public class RandomFixedSizedExemplarReservoir : FixedSizedExemplarReservoir {
    
    private init(clock: Clock, size: Int, mapAndResetCell: @escaping (ReservoirCell, [String : AttributeValue]) -> ExemplarData?) {
        super.init(clock:clock, size: size, reservoirCellSelector: RandomCellSelector() , mapAndResetCell : mapAndResetCell)
    }
    
    static func createLong(clock: Clock, size : Int) -> RandomFixedSizedExemplarReservoir {
        
        return RandomFixedSizedExemplarReservoir(clock: clock, size: size, mapAndResetCell: unsafeBitCast(ReservoirCell.getAndResetLong, to: ((ReservoirCell, [String: AttributeValue]) -> ImmutableLongExemplarData).self))
        
    }
    
    static func createDouble(clock: Clock, size : Int) -> RandomFixedSizedExemplarReservoir {
        return RandomFixedSizedExemplarReservoir(clock: clock, size: size, mapAndResetCell: unsafeBitCast(ReservoirCell.getAndResetDouble, to: ((ReservoirCell, [String: AttributeValue]) -> ImmutableDoubleExemplarData).self))

    }
    
    class RandomCellSelector : ReservoirCellSelector {
        var numMeasurments : Int = 0
        
        
        func reservoirCellIndex(for cells: [ReservoirCell], value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) -> Int {
            return getIndex(cells: cells)
            
        }
        
        func reservoirCellIndex(for cells: [ReservoirCell], value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) -> Int {
            return getIndex(cells: cells)

        }
        
        
        func reset() {
            numMeasurments = 0
        }
        
        private func getIndex(cells: [ReservoirCell]) -> Int {
            let count = numMeasurments + 1
            let index = Int.random(in: Int.min...Int.max) > 0 ? count : 1
            numMeasurments += 1
            if (index < cells.count) {
                return index
            }
            return -1
        }
        
    }
}


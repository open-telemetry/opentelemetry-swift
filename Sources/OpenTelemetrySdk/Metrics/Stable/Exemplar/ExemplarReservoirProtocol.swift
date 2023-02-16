//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol ExemplarReservoirProtocol {
    associatedtype T : ExemplarData
    func offerDoubleMeasurement(value: Double, attributes: [String: AttributeValue])
    func offerLongMeasurement(value: Int, attributes: [String: AttributeValue])
    func collectAndReset(attribute: [String: AttributeValue]) -> [T]
}

public class ExemplarReservoir<T : ExemplarData> : ExemplarReservoirProtocol {
   
    public func collectAndReset(attribute: [String : AttributeValue]) -> [T] {
        return [T]()
    }
    
    
    public func offerDoubleMeasurement(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        
    }
    
    public func offerLongMeasurement(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        
    }
    
    
    static func filter<T:ExemplarData>(filter: ExemplarFilter, original : ExemplarReservoir<T>) -> ExemplarReservoir<T> {
        return FilteredExemplarReservoir<T>(filter: filter, reservoir: original)
    }
    
    static func doubleNoSamples() -> ExemplarReservoir<ImmutableDoubleExemplarData> {
        return NoopExemplarReservoir<ImmutableDoubleExemplarData>()
    }
    
    static func longNoSamples() -> ExemplarReservoir<ImmutableLongExemplarData> {
        return NoopExemplarReservoir<ImmutableLongExemplarData>()
    }
    
    
}


public class NoopExemplarReservoir<T : ExemplarData> : ExemplarReservoir<T> {
    public override func offerDoubleMeasurement(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        // noop
    }
    
    public override func offerLongMeasurement(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        // noop
    }
    
    public override func collectAndReset(attribute: [String : AttributeValue]) -> [T] {
        return [T]()
    }
    
    
}



public class FixedSizedExemplarReservoir<T : ExemplarData> : ExemplarReservoir<T> {
    let storage : [ReservoirCell]
    let reservoirCellSelector : ReservoirCellSelector
    let mapAndResetCell : (ReservoirCell, [String:AttributeValue])-> T?
    var hasMeasurements = false
    
    init(clock: Clock, size: Int, reservoirCellSelector: ReservoirCellSelector, mapAndResetCell: @escaping (ReservoirCell, [String : AttributeValue]) -> T) {
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
    
    override public func collectAndReset(attribute: [String : AttributeValue]) -> [T] {
       var results = [T]()
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

public class RandomFixedSizedExemplarReservoir<T: ExemplarData> : FixedSizedExemplarReservoir<T> {
    
    private init(clock: Clock, size: Int, mapAndResetCell: @escaping (ReservoirCell, [String : AttributeValue]) -> T) {
        super.init(clock:clock, size: size, reservoirCellSelector: RandomCellSelector() , mapAndResetCell : mapAndResetCell)
    }
    
    static func createLong(clock: Clock, size : Int) -> RandomFixedSizedExemplarReservoir<ImmutableLongExemplarData> {
        
        return RandomFixedSizedExemplarReservoir<ImmutableLongExemplarData>(clock: clock, size: size, mapAndResetCell: unsafeBitCast(ReservoirCell.getAndResetLong, to: ((ReservoirCell, [String: AttributeValue]) -> ImmutableLongExemplarData).self))
        
    }
    
    static func createDouble(clock: Clock, size : Int) -> RandomFixedSizedExemplarReservoir<ImmutableDoubleExemplarData> {
        return RandomFixedSizedExemplarReservoir<ImmutableDoubleExemplarData>(clock: clock, size: size, mapAndResetCell: unsafeBitCast(ReservoirCell.getAndResetDouble, to: ((ReservoirCell, [String: AttributeValue]) -> ImmutableDoubleExemplarData).self))

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


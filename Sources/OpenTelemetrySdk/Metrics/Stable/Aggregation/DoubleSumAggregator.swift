//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


public class DoubleSumAggregator: SumAggregator, StableAggregator {
    private let reservoirSupplier : () -> AnyExemplarReservoir

    
    public func diff(previousCumulative: AnyPointData, currentCumulative: AnyPointData) throws -> AnyPointData {
        currentCumulative - previousCumulative
    }
    
    public func toPoint(measurement: Measurement) throws -> AnyPointData {
        ImmutableDoublePointData(startEpochNanos: measurement.startEpochNano, endEpochNanos: measurement.epochNano, attributes: measurement.attributes, exemplars: [ExemplarData](), value: measurement.doubleValue)
    }
    
    public func createHandle() -> AggregatorHandle {
        Handle(exemplarReservoir: reservoirSupplier())
    }
    
    public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [AnyPointData], temporality: AggregationTemporality) -> StableMetricData {
        StableMetricData.createDoubleSum(resource: resource, instrumentationScopeInfo: scope, name:descriptor.instrument.name , description: descriptor.instrument.description, unit:descriptor.instrument.unit, data: StableSumData(aggregationTemporality: temporality, points: points as! [ImmutableDoublePointData]))
    }
    
    init(instrumentDescriptor: InstrumentDescriptor, reservoirSupplier : @escaping () -> AnyExemplarReservoir) {
        self.reservoirSupplier = reservoirSupplier
        super.init(instrumentDescriptor: instrumentDescriptor)
    }
    
    private class Handle: AggregatorHandle {
        var sum : Double = 0
        var sumLock = Lock()
        
        override func doAggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String : AttributeValue], exemplars: [ExemplarData], reset: Bool) -> AnyPointData {
            var value = 0.0
            sumLock.withLockVoid {
                if reset {
                    value = sum
                    sum = 0
                } else {
                    value = sum
                }
            }
            
            return ImmutableDoublePointData(startEpochNanos: startEpochNano, endEpochNanos: endEpochNano, attributes: attributes, exemplars: exemplars, value: value)
        }
        
        override func doRecordDouble(value: Double) {
            sumLock.withLockVoid {
                sum += value
            }
        }
    }

}

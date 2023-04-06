//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public enum HistogramAggregatorError : Error {
    case unsupportedOperation(String)
}

public class DoubleExplicitBucketHistogramAggregator : StableAggregator {
    

    class Handle : AggregatorHandle {
        
        let lock = Lock()
        
        internal init(boundries : [Double], exemplarReservoir: AnyExemplarReservoir) {
            self.boundries = boundries
            
            self.sum = 0
            self.min = Double.greatestFiniteMagnitude
            self.max = -1
            self.count = 0
            self.counts = Array(repeating: 0, count: boundries.count + 1)
            super.init(exemplarReservoir: exemplarReservoir)

        }
        
        private var boundries : [Double]
        private var sum : Double
        private var min : Double
        private var max : Double
        private var count : UInt64
        private var counts : [Int]
        
        override func doAggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String : AttributeValue], exemplars: [ExemplarData], reset: Bool) -> AnyPointData {
            
            lock.lock()
            defer {
                lock.unlock()
            }
            let pointData =  HistogramPointData(startEpochNanos: startEpochNano, endEpochNanos: endEpochNano, attributes: attributes, exemplars: exemplars, sum: sum, count: count, min: min, max: max, boundries: boundries, counts: counts, hasMin: count > 0, hasMax: count > 0)
            
            if (reset) {
                sum = 0
                min = Double.greatestFiniteMagnitude
                max = -1
                count = 0
                counts = Array(repeating: 0, count: boundries.count + 1)
            }
            
            return pointData
        }
        

        override func doRecordLong(value: Int) {
            doRecordDouble(value: Double(value))
        }

        override func doRecordDouble(value: Double) {
            lock.lock()
            defer {
                lock.unlock()
            }
            var bucketIndex = -1
            for (index, boundry) in boundries.enumerated() {
                if value <= boundry {
                    bucketIndex = index
                    break
                }
            }
            if bucketIndex == -1 {
                bucketIndex = boundries.count
            }
            
            sum += value
            min = Swift.min(min, value)
            max = Swift.max(max, value)
            count += 1
            counts[bucketIndex] += 1
        }
        
    }
    
    private let boundries : [Double]
    private let reservoirSupplier : () -> AnyExemplarReservoir
    
    public init(boundries: [Double], reservoirSupplier :  @escaping () -> AnyExemplarReservoir) {
        self.boundries = boundries
        self.reservoirSupplier = reservoirSupplier
    }
    
    public func diff(previousCumulative: AnyPointData, currentCumulative: AnyPointData) throws -> AnyPointData {
        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support diff.")
    }
    
    public func toPoint(measurement: Measurement) throws -> AnyPointData {
        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support toPoint.")
    }
    
    public func createHandle() -> AggregatorHandle {
        return Handle(boundries: self.boundries, exemplarReservoir: self.reservoirSupplier())
    }
    
    public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [AnyPointData], temporality: AggregationTemporality) -> StableMetricData {
        StableMetricData.createHistogram(resource: resource, instrumentationScopeInfo: scope, name: descriptor.name, description: descriptor.description, unit: descriptor.instrument.unit, data: StableHistogramData(aggregationTemporality: temporality, points: points as! [HistogramPointData]))
    }
}
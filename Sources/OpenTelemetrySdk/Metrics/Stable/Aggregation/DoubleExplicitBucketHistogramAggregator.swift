//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public enum HistogramAggregatorError: Error {
    case unsupportedOperation(String)
}

public class DoubleExplicitBucketHistogramAggregator: StableAggregator {
    class Handle: AggregatorHandle {
        let lock = Lock()
        
        internal init(boundaries: [Double], exemplarReservoir: ExemplarReservoir) {
            self.boundaries = boundaries
            
            self.sum = 0
            self.min = Double.greatestFiniteMagnitude
            self.max = -1
            self.count = 0
            self.counts = Array(repeating: 0, count: boundaries.count + 1)
            super.init(exemplarReservoir: exemplarReservoir)
        }
        
        private var boundaries: [Double]
        private var sum: Double
        private var min: Double
        private var max: Double
        private var count: UInt64
        private var counts: [Int]
        
        override func doAggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData], reset: Bool) -> PointData {
            lock.lock()
            defer {
                lock.unlock()
            }
            let pointData = HistogramPointData(startEpochNanos: startEpochNano, endEpochNanos: endEpochNano, attributes: attributes, exemplars: exemplars, sum: sum, count: count, min: min, max: max, boundaries: boundaries, counts: counts, hasMin: count > 0, hasMax: count > 0)
            
            if reset {
                sum = 0
                min = Double.greatestFiniteMagnitude
                max = -1
                count = 0
                counts = Array(repeating: 0, count: boundaries.count + 1)
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
            for (index, boundry) in boundaries.enumerated() {
                if value <= boundry {
                    bucketIndex = index
                    break
                }
            }
            if bucketIndex == -1 {
                bucketIndex = boundaries.count
            }
            
            sum += value
            min = Swift.min(min, value)
            max = Swift.max(max, value)
            count += 1
            counts[bucketIndex] += 1
        }
    }
    
    private let boundaries: [Double]
    private let reservoirSupplier: () -> ExemplarReservoir
    
    public init(boundaries: [Double], reservoirSupplier: @escaping () -> ExemplarReservoir) {
        self.boundaries = boundaries
        self.reservoirSupplier = reservoirSupplier
    }
    
    public func diff(previousCumulative: PointData, currentCumulative: PointData) throws -> PointData {
        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support diff.")
    }
    
    public func toPoint(measurement: Measurement) throws -> PointData {
        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support toPoint.")
    }
    
    public func createHandle() -> AggregatorHandle {
        return Handle(boundaries: self.boundaries, exemplarReservoir: self.reservoirSupplier())
    }
    
    public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [PointData], temporality: AggregationTemporality) -> StableMetricData {
        StableMetricData.createHistogram(resource: resource, instrumentationScopeInfo: scope, name: descriptor.name, description: descriptor.description, unit: descriptor.instrument.unit, data: StableHistogramData(aggregationTemporality: temporality, points: points as! [HistogramPointData]))
    }
}

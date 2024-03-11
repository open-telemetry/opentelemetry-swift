//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleBase2ExponentialHistogramAggregator: StableAggregator {
    private var reservoirSupplier : () -> ExemplarReservoir
    private var maxBuckets : Int
    private var maxScale: Int

    init(maxBuckets: Int, maxScale: Int, reservoirSupplier: @escaping () -> ExemplarReservoir) {
        self.maxBuckets = maxBuckets
        self.maxScale = maxScale
        self.reservoirSupplier = reservoirSupplier
    }

    public func diff(previousCumulative: PointData, currentCumulative: PointData) throws -> PointData {
        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support diff.")
    }

    public func toPoint(measurement: Measurement) throws -> PointData {
        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support toPoint.")
    }

    public func createHandle() -> AggregatorHandle {
        return Handle(maxBuckets: self.maxBuckets, maxScale: self.maxScale, exemplarReservoir: self.reservoirSupplier())
    }

    public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [PointData], temporality: AggregationTemporality) -> StableMetricData {
        StableMetricData.createExponentialHistogram(resource: resource, instrumentationScopeInfo: scope, name: descriptor.name, description: descriptor.description, unit: descriptor.instrument.unit, data: StableExponentialHistogramData(aggregationTemporality: temporality, points: points))
    }

    class Handle : AggregatorHandle {
        let lock = Lock()
        var maxBuckets : Int
        var maxScale: Int

        var zeroCount: UInt64
        var sum: Double
        var min: Double
        var max: Double
        var count: UInt64
        var scale: Int

        var positiveBuckets: DoubleBase2ExponentialHistogramBuckets?
        var negativeBuckets: DoubleBase2ExponentialHistogramBuckets?

        internal init(maxBuckets: Int, maxScale: Int, exemplarReservoir: ExemplarReservoir) {
            self.maxBuckets = maxBuckets
            self.maxScale = maxScale
            
            self.sum = 0
            self.zeroCount = 0
            self.min = Double.greatestFiniteMagnitude
            self.max = -1
            self.count = 0
            self.scale = maxScale
            
            super.init(exemplarReservoir: exemplarReservoir)
        }

        override func doRecordLong(value: Int) {
            doRecordDouble(value: Double(value))
        }

        override func doAggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String : AttributeValue], exemplars: [ExemplarData], reset: Bool) -> PointData {
            lock.lock()
            defer {
                lock.unlock()
            }
            
            let pointData = ExponentialHistogramPointData(
                scale: self.scale,
                sum: self.sum,
                zeroCount: Int64(self.zeroCount),
                hasMin: self.count > 0,
                hasMax: self.count > 0,
                min: self.min,
                max: self.max,
                positiveBuckets: resolveBuckets(buckets: self.positiveBuckets, scale: self.scale, reset: reset),
                negativeBuckets: resolveBuckets(buckets: self.negativeBuckets, scale: self.scale, reset: reset),
                startEpochNanos: startEpochNano,
                epochNanos: endEpochNano,
                attributes: attributes,
                exemplars: exemplars
            )
            
            if reset {
                self.sum = 0
                self.zeroCount = 0
                self.min = Double.greatestFiniteMagnitude
                self.max = -1
                self.count = 0
                self.scale = self.maxScale
            }
            
            return pointData
        }

        override func doRecordDouble(value: Double) {
            lock.lock()
            defer {
                lock.unlock()
            }
            
            if !value.isFinite {
                return
            }
            
            sum += value
            
            min = Swift.min(min, value)
            max = Swift.max(max, value)
            count += 1
            
            var buckets: DoubleBase2ExponentialHistogramBuckets
            if value == 0.0 {
                self.zeroCount += 1
                return
            } else if value > 0.0 {
                if let positiveBuckets = self.positiveBuckets {
                    buckets = positiveBuckets
                } else {
                    buckets = DoubleBase2ExponentialHistogramBuckets(scale: self.scale, maxBuckets: self.maxBuckets)
                    self.positiveBuckets = buckets
                }
            } else {
                if let negativeBuckets = self.negativeBuckets {
                    buckets = negativeBuckets
                } else {
                    buckets = DoubleBase2ExponentialHistogramBuckets(scale: self.scale, maxBuckets: self.maxBuckets)
                    self.negativeBuckets = buckets
                }
            }
            
            if !buckets.record(value: value) {
                downScale(by: buckets.getScaleReduction(value))
                buckets.record(value: value)
            }
        }

        private func resolveBuckets(buckets: DoubleBase2ExponentialHistogramBuckets?, scale: Int, reset: Bool) -> ExponentialHistogramBuckets {
            guard let buckets = buckets else {
                return EmptyExponentialHistogramBuckets(scale: scale)
            }
            
            let copy = buckets.copy() as! DoubleBase2ExponentialHistogramBuckets
            
            if reset {
                buckets.clear(scale: self.maxScale)
            }
            
            return copy
        }

        func downScale(by: Int) {
            if let positiveBuckets = self.positiveBuckets {
                positiveBuckets.downscale(by: by)
                scale = positiveBuckets.scale
                
            }
            
            if let negativeBuckets = self.negativeBuckets {
                negativeBuckets.downscale(by: by)
                scale = negativeBuckets.scale
            }
        }
    }
}

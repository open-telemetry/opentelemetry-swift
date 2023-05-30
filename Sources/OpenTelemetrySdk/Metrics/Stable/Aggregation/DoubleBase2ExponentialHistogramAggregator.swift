////
//// Copyright The OpenTelemetry Authors
//// SPDX-License-Identifier: Apache-2.0
////
//
//import Foundation
//
//public class DoubleBase2ExponentialHistogramAggregator: StableAggregator {
//    private var reservoirSupplier : () -> AnyExemplarReservoir
//    private var maxBuckets : Int
//    private var maxScale: Int
//
//    init(reservoirSupplier: @escaping () -> AnyExemplarReservoir, maxBuckets: Int, maxScale: Int) {
//        self.reservoirSupplier = reservoirSupplier
//        self.maxBuckets = maxBuckets
//        self.maxScale = maxScale
//    }
//
//    public func diff(previousCumulative: AnyPointData, currentCumulative: AnyPointData) throws -> AnyPointData {
//        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support diff.")
//    }
//
//    public func toPoint(measurement: Measurement) throws -> AnyPointData {
//        throw HistogramAggregatorError.unsupportedOperation("This aggregator does not support toPoint.")
//    }
//
//
//    public func createHandle() -> AggregatorHandle {
//        <#code#>
//    }
//
//    public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [AnyPointData], temporality: AggregationTemporality) -> StableMetricData {
//        StableMetricData.createExponentialHistogram(resource: resource, instrumentationScopeInfo: scope, name: descriptor.name, description: descriptor.description, unit: descriptor.instrument.unit, data: StableExponentialHistogramData(aggregationTemporality: temporality, points: points))
//    }
//
//    private class Handle : AggregatorHandle {
//        var maxBuckets : Int
//
//    }
//}

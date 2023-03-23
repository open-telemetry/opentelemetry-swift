//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi
public class DropAggregator : StableAggregator {
    
    
    public private(set) static var POINT_DATA = AnyPointData(startEpochNanos: 0,endEpochNanos: 0,attributes: [String:AttributeValue](), exemplars: [ExemplarData]())

    
    public func createHandle() -> AggregatorHandle {
        AggregatorHandle(exemplarReservoir: ExemplarReservoirCollection.doubleNoSamples())
    }
    
    public func diff(previousCumulative: AnyPointData, currentCumulative: AnyPointData) -> AnyPointData {
        Self.POINT_DATA
    }
    
    public func toPoint(measurement: Measurement) -> AnyPointData {
        Self.POINT_DATA
    }
    
    public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [AnyPointData], temporality: AggregationTemporality) -> StableMetricData {
        StableMetricData.empty
    }
    
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol StableAggregator {

    
    func diff(previousCumulative : AnyPointData , currentCumulative: AnyPointData) throws -> AnyPointData
    
    func toPoint(measurement: OpenTelemetrySdk.Measurement) throws -> AnyPointData

    func createHandle() -> AggregatorHandle
    
    func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [AnyPointData], temporality: AggregationTemporality) -> StableMetricData
    
}

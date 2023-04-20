//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public protocol StableAggregator {
    func diff(previousCumulative: PointData, currentCumulative: PointData) throws -> PointData
    func toPoint(measurement: OpenTelemetrySdk.Measurement) throws -> PointData
    func createHandle() -> AggregatorHandle
    func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [PointData], temporality: AggregationTemporality) -> StableMetricData
}

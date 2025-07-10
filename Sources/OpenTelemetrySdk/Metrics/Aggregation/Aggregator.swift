//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "Aggregator")
public typealias StableAggregator = Aggregator

public protocol Aggregator {
  func diff(previousCumulative: PointData, currentCumulative: PointData) throws -> PointData
  func toPoint(measurement: OpenTelemetrySdk.Measurement) throws -> PointData
  func createHandle() -> AggregatorHandle
  func toMetricData(
    resource: Resource,
    scope: InstrumentationScopeInfo,
    descriptor: MetricDescriptor,
    points: [PointData],
    temporality: AggregationTemporality
  ) -> MetricData
}

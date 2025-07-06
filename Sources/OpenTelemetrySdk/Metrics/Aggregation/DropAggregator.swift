//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DropAggregator: Aggregator {
  public private(set) static var POINT_DATA = PointData(startEpochNanos: 0, endEpochNanos: 0, attributes: [String: AttributeValue](), exemplars: [ExemplarData]())

  public func createHandle() -> AggregatorHandle {
    AggregatorHandle(exemplarReservoir: ExemplarReservoirCollection.doubleNoSamples())
  }

  public func diff(previousCumulative: PointData, currentCumulative: PointData) -> PointData {
    Self.POINT_DATA
  }

  public func toPoint(measurement: Measurement) -> PointData {
    Self.POINT_DATA
  }

  public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [PointData], temporality: AggregationTemporality) -> MetricData {
    MetricData.empty
  }
}

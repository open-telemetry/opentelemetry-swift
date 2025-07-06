//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleLastValueAggregator: Aggregator {
  private var reservoirSupplier: () -> ExemplarReservoir

  init(reservoirSupplier: @escaping () -> ExemplarReservoir) {
    self.reservoirSupplier = reservoirSupplier
  }

  public func diff(previousCumulative: PointData, currentCumulative: PointData) throws -> PointData {
    currentCumulative
  }

  public func toPoint(measurement: Measurement) throws -> PointData {
    DoublePointData(startEpochNanos: measurement.startEpochNano, endEpochNanos: measurement.epochNano, attributes: measurement.attributes, exemplars: [ExemplarData](), value: measurement.doubleValue)
  }

  public func createHandle() -> AggregatorHandle {
    Handle(exemplarReservoir: reservoirSupplier())
  }

  public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [PointData], temporality: AggregationTemporality) -> MetricData {
    MetricData
      .createDoubleGauge(
        resource: resource,
        instrumentationScopeInfo: scope,
        name: descriptor.name,
        description: descriptor.description,
        unit: descriptor.instrument.unit,
        data: GaugeData(
          aggregationTemporality: temporality,
          points: points
        )
      )
  }

  private class Handle: AggregatorHandle {
    private var value: Double = 0
    private var valueLock = Lock()
    override func doAggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData], reset: Bool) -> PointData {
      var result = 0.0
      valueLock.withLockVoid {
        result = value
        if reset {
          value = 0
        }
      }
      return DoublePointData(startEpochNanos: startEpochNano, endEpochNanos: endEpochNano, attributes: attributes, exemplars: exemplars, value: result)
    }

    override func doRecordDouble(value: Double) {
      valueLock.withLockVoid {
        self.value = value
      }
    }
  }
}

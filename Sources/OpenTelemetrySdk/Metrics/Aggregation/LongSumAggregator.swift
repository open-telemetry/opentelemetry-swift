//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongSumAggregator: SumAggregator, Aggregator {
  private let reservoirSupplier: () -> ExemplarReservoir

  init(descriptor: InstrumentDescriptor, reservoirSupplier: @escaping () -> ExemplarReservoir) {
    self.reservoirSupplier = reservoirSupplier
    super.init(instrumentDescriptor: descriptor)
  }

  public func diff(previousCumulative: PointData, currentCumulative: PointData) throws -> PointData {
    return currentCumulative - previousCumulative
  }

  public func toPoint(measurement: Measurement) throws -> PointData {
    LongPointData(startEpochNanos: measurement.startEpochNano, endEpochNanos: measurement.epochNano, attributes: measurement.attributes, exemplars: [ExemplarData](), value: measurement.longValue)
  }

  public func createHandle() -> AggregatorHandle {
    Handle(exemplarReservoir: reservoirSupplier())
  }

  public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [PointData], temporality: AggregationTemporality) -> MetricData {
    MetricData
      .createLongSum(
        resource: resource,
        instrumentationScopeInfo: scope,
        name: descriptor.instrument.name,
        description: descriptor.instrument.description,
        unit: descriptor.instrument.unit,
        isMonotonic: isMonotonic,
        data: SumData(
          aggregationTemporality: temporality,
          points: points as! [LongPointData]
        )
      )
  }

  private class Handle: AggregatorHandle {
    var sum: Int = 0
    var sumLock = Lock()

    override func doAggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData], reset: Bool) -> PointData {
      var value = 0
      sumLock.withLockVoid {
        if reset {
          value = sum
          sum = 0
        } else {
          value = sum
        }
      }

      return LongPointData(startEpochNanos: startEpochNano, endEpochNanos: endEpochNano, attributes: attributes, exemplars: exemplars, value: value)
    }

    override func doRecordLong(value: Int) {
      sumLock.withLockVoid {
        sum += value
      }
    }
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public enum HistogramAggregatorError: Error {
  case unsupportedOperation(String)
}

public class DoubleExplicitBucketHistogramAggregator: Aggregator {
  class Handle: AggregatorHandle {
    let lock = Lock()

    init(boundaries: [Double], exemplarReservoir: ExemplarReservoir) {
      self.boundaries = boundaries

      sum = 0
      self.min = Double.greatestFiniteMagnitude
      self.max = -1
      count = 0
      counts = Array(repeating: 0, count: boundaries.count + 1)
      super.init(exemplarReservoir: exemplarReservoir)
    }

    var boundaries: [Double]
    var sum: Double
    var min: Double
    var max: Double
    var count: UInt64
    var counts: [Int]

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
      for (index, boundary) in boundaries.enumerated() where value <= boundary {
        bucketIndex = index
        break
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

  let boundaries: [Double]
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
    return Handle(boundaries: boundaries, exemplarReservoir: reservoirSupplier())
  }

  public func toMetricData(resource: Resource, scope: InstrumentationScopeInfo, descriptor: MetricDescriptor, points: [PointData], temporality: AggregationTemporality) -> MetricData {
    MetricData
      .createHistogram(
        resource: resource,
        instrumentationScopeInfo: scope,
        name: descriptor.name,
        description: descriptor.description,
        unit: descriptor.instrument.unit,
        data: HistogramData(
          aggregationTemporality: temporality,
          points: points as! [HistogramPointData]
        )
      )
  }
}

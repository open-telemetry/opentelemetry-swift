//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

protocol AggregatorHandleProtocol {
  func doAggregateThenMaybeReset(startEpochNano: Int, endEpochNano: Int, attributes: [String: AttributeValue], reset: Bool) -> PointData
  func doRecordLong(value: Int)
  func doRecordDouble(value: Double)
}

public class AggregatorHandle {
  let exemplarReservoir: ExemplarReservoir

  init(exemplarReservoir: ExemplarReservoir) {
    self.exemplarReservoir = exemplarReservoir
  }

  public func aggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String: AttributeValue], reset: Bool) -> PointData {
    doAggregateThenMaybeReset(startEpochNano: startEpochNano, endEpochNano: endEpochNano, attributes: attributes, exemplars: exemplarReservoir.collectAndReset(attribute: attributes), reset: reset)
  }

  public func recordLong(value: Int, attributes: [String: AttributeValue]) {
    exemplarReservoir.offerLongMeasurement(value: value, attributes: attributes)
    recordLong(value: value)
  }

  public func recordLong(value: Int) {
    doRecordLong(value: value)
  }

  public func recordDouble(value: Double, attributes: [String: AttributeValue]) {
    exemplarReservoir.offerDoubleMeasurement(value: value, attributes: attributes)
    recordDouble(value: value)
  }

  public func recordDouble(value: Double) {
    doRecordDouble(value: value)
  }

  func doRecordDouble(value: Double) { fatalError() } // TODO: better way to force subclass override

  func doRecordLong(value: Int) { fatalError() }

  func doAggregateThenMaybeReset(startEpochNano: UInt64, endEpochNano: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData], reset: Bool) -> PointData { fatalError() }
}

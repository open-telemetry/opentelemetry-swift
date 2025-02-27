//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class FilteredExemplarReservoir: ExemplarReservoir {
  let exemplarFilter: ExemplarFilter
  let reservoir: ExemplarReservoir

  init(filter: ExemplarFilter, reservoir: ExemplarReservoir) {
    exemplarFilter = filter
    self.reservoir = reservoir
  }

  override public func offerDoubleMeasurement(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    if exemplarFilter.shouldSampleMeasurement(value: value, attributes: attributes) {
      reservoir.offerDoubleMeasurement(value: value, attributes: attributes)
    }
  }

  override public func offerLongMeasurement(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    if exemplarFilter.shouldSampleMeasurement(value: value, attributes: attributes) {
      reservoir.offerLongMeasurement(value: value, attributes: attributes)
    }
  }

  override public func collectAndReset(attribute: [String: OpenTelemetryApi.AttributeValue]) -> [ExemplarData] {
    return reservoir.collectAndReset(attribute: attribute)
  }
}

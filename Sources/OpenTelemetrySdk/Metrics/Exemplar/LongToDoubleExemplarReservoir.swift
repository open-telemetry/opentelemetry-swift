//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongToDoubleExemplarReservoir: ExemplarReservoir {
  let reservoir: ExemplarReservoir

  public init(reservoir: ExemplarReservoir) {
    self.reservoir = reservoir
  }

  override public func collectAndReset(attribute: [String: AttributeValue]) -> [ExemplarData] {
    return reservoir.collectAndReset(attribute: attribute)
  }

  override public func offerDoubleMeasurement(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    return reservoir.offerDoubleMeasurement(value: value, attributes: attributes)
  }

  override public func offerLongMeasurement(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    return offerDoubleMeasurement(value: Double(value), attributes: attributes)
  }
}

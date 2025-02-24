//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class HistogramExemplarReservoir: FixedSizedExemplarReservoir {
  init(clock: Clock, boundaries: [Double]) {
    super.init(clock: clock, size: boundaries.count + 1, reservoirCellSelector: HistogramCellSelector(boundaries: boundaries), mapAndResetCell: { cell, attributes in
      return cell.getAndResetDouble(pointAttributes: attributes)
    })
  }

  override public func offerLongMeasurement(value: Int, attributes: [String: AttributeValue]) {
    super.offerDoubleMeasurement(value: Double(value), attributes: attributes)
  }

  class HistogramCellSelector: ReservoirCellSelector {
    private var boundaries: [Double]

    init(boundaries: [Double]) {
      self.boundaries = boundaries
    }

    func reservoirCellIndex(for cells: [ReservoirCell], value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Int {
      reservoirCellIndex(for: cells, value: Double(value), attributes: attributes)
    }

    func reservoirCellIndex(for cells: [ReservoirCell], value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Int {
      if let index = boundaries.firstIndex(where: { boundary in
        value <= boundary
      }) {
        return index
      }
      return boundaries.count
    }

    func reset() {
      // noop
    }
  }
}

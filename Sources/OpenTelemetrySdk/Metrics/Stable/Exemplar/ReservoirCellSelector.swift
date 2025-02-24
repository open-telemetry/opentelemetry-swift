//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public protocol ReservoirCellSelector {
  func reservoirCellIndex(for cells: [ReservoirCell], value: Int, attributes: [String: AttributeValue]) -> Int

  func reservoirCellIndex(for cells: [ReservoirCell], value: Double, attributes: [String: AttributeValue]) -> Int

  func reset()
}

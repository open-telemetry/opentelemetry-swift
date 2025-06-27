//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol DoubleGauge {
  mutating func record(value: Double)
  mutating func record(value: Double, attributes: [String: AttributeValue])
}

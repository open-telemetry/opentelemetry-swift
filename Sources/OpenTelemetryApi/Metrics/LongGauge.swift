//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol LongGauge {
  mutating func record(value: Int)
  mutating func record(value: Int, attributes: [String: AttributeValue])
}

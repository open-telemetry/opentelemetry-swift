/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleUpDownCounter {
    mutating func add(value: Double)
    mutating func add(value: Double, attributes: [String: AttributeValue])
}

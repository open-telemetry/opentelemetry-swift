/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongUpDownCounter {
    mutating func add(value: Int)
    mutating func add(value: Int, attributes: [String: AttributeValue])
}

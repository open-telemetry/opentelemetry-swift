/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongCounter {
    mutating func add(value: Int)
    mutating func add(value: Int, attribute: [String: AttributeValue])
}

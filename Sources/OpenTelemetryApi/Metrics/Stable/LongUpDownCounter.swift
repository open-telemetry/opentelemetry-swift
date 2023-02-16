/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongUpDownCounter {
    func add(value: Int)
    func add(value: Int, attributes: [String: AttributeValue])
}

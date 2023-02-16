/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongCounter {
    func add(value: Int)

    func add(value: Int, attribute: [String: AttributeValue])
}

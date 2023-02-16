/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleUpDownCounter {

    func add(value: Double)
    func add(value: Double, attributes: [String: AttributeValue])
}

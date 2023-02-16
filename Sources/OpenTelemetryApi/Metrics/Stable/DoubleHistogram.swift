/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleHistogram {
    func record(value: Double)
    func record(value: Double, attributes: [String: AttributeValue])

}

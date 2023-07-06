/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ObservableLongMeasurement {
    func record(value: Int)
    func record(value: Int, attributes: [String: AttributeValue])
}

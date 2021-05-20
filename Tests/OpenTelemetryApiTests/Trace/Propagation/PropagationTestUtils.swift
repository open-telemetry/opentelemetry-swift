/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

struct TestSetter: Setter {
    func set(carrier: inout [String: String], key: String, value: String) {
        carrier[key] = value
    }
}

struct TestGetter: Getter {
    func get(carrier: [String: String], key: String) -> [String]? {
        if let value = carrier[key] {
            return [value]
        }
        return nil
    }
}

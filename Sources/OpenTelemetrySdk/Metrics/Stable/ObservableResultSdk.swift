/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class ObservableResultSdk<T> : ObservableResult {
    var value : T?
    var attributes = [String: AttributeValue]()

    init() {}

    public func observe(_ value: T, attributes: [String: AttributeValue]?) {
        self.value = value
        if let a = attributes {
            self.attributes = a
        }

    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class StableCounterMeasurementSdk<T: Numeric> : StableCounterMeasurement {
    var value : T = 0
    var count : UInt = 0

    init () {}

    init(value: T) {
        self.value = value
        count += 1
    }
    public func add(value: T) {
        self.value += value
        count += 1
    }
}

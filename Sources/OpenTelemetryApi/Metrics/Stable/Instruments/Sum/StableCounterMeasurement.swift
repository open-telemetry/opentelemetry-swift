/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol StableCounterMeasurement {
    associatedtype T : Numeric
    func add (value:T)
}

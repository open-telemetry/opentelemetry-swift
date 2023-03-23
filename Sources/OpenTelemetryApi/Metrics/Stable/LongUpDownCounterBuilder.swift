/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongUpDownCounterBuilder {
    func ofDoubles() -> DoubleUpDownCounterBuilder
    func build() -> LongUpDownCounter
    mutating func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongUpDownCounter
}

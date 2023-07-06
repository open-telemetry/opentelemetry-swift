/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongUpDownCounterBuilder : AnyObject {
    func ofDoubles() -> DoubleUpDownCounterBuilder
    func build() -> LongUpDownCounter
    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongUpDownCounter
}

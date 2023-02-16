/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongUpDownCounterBuilder {
    func setDescription(description: String) -> Self
    func setUnit(unit: String) -> Self
    func ofDoubles() -> DoubleUpDownCounterBuilder

    func build() -> LongUpDownCounter
    func buildWithCallback(_ callback: (ObservableLongMeasurement) -> Void) -> ObservableLongUpDownCounter
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongCounterBuilder {

    func setDescription(description: String) -> Self

    func setUnit(unit: String) -> Self

    func ofDoubles() -> DoubleCounterBuilder

    func build() -> LongCounter

    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongCounter
}

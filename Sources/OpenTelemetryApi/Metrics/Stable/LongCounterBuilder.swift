/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongCounterBuilder {

    func ofDoubles() -> DoubleCounterBuilder

    func build() -> LongCounter

    mutating func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongCounter
}



/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongCounterBuilder : AnyObject {
    func ofDoubles() -> DoubleCounterBuilder
    func build() -> LongCounter
    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongCounter
}



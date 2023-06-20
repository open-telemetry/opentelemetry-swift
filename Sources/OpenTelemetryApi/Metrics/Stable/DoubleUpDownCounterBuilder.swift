/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleUpDownCounterBuilder : AnyObject {
    func build() -> DoubleUpDownCounter
    func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleUpDownCounter

}


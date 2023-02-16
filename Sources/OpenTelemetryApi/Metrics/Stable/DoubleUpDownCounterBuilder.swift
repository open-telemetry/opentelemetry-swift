/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleUpDownCounterBuilder {
    func setDescription(description: String) -> Self
    func setUnit(unit: String) -> Self
    func build() -> DoubleUpDownCounter
    func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleUpDownCounter

}


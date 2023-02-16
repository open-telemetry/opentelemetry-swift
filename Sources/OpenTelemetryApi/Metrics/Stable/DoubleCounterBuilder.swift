/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleCounterBuilder {
    func setDescription(description: String) -> Self
    func setUnit(unit: String) -> Self
    func build() -> DoubleCounter

    func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleCounter
}

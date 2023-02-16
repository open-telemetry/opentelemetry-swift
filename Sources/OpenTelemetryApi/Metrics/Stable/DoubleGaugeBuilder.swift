/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleGaugeBuilder {
    func setDescription(description: String) -> Self
    func setUnit(unit: String) -> Self

    func ofLongs() -> LongGaugeBuilder
    func buildWithCallback(_ callback: (ObservableDoubleMeasurement)->Void) -> ObservableDoubleGauge
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleGaugeBuilder {
    func ofLongs() -> LongGaugeBuilder
    mutating func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement)->Void) -> ObservableDoubleGauge
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongGaugeBuilder : AnyObject {
    func setUnit(_ unit: String) -> LongGaugeBuilder
    func setDescription(_ description: String) -> LongGaugeBuilder
    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongGauge
}

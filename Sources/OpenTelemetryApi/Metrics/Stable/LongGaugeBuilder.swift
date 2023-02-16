/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongGaugeBuilder {
    func setDescription(description: String) -> Self
    func setUnit(unit: String) -> Self
    func buildWithCallback(_ callback: (ObservableLongMeasurement) -> Void) -> ObservableLongGauge
}

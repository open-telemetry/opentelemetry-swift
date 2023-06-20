/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongGaugeBuilder : AnyObject {
    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongGauge
}

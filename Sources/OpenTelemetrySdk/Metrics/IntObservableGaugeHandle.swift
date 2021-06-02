/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

struct IntObservableGaugeHandle: IntObserverMetricHandle {
    public private(set) var aggregator = MaxValueAggregator<Int>()

    func observe(value: Int) {
        aggregator.update(value: value)
    }
}

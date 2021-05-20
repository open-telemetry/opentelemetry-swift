/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

internal class BoundMeasureMetricSdk<T: SignedNumeric & Comparable>: BoundMeasureMetricSdkBase<T> {
    private var measureAggregator = MeasureMinMaxSumCountAggregator<T>()

    override init() {
        super.init()
    }

    override func record(value: T) {
        measureAggregator.update(value: value)
    }

    override func getAggregator() -> MeasureMinMaxSumCountAggregator<T> {
        return measureAggregator
    }
}

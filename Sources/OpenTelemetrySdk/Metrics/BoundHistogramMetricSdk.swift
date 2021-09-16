/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

internal class BoundHistogramMetricSdk<T: SignedNumeric & Comparable>: BoundHistogramMetricSdkBase<T> {
    private var histogramAggregator: HistogramAggregator<T>

    override init(boundaries: Array<T>) {
        self.histogramAggregator = try! HistogramAggregator(boundaries: boundaries)
        super.init(boundaries: boundaries)
    }

    override func record(value: T) {
        histogramAggregator.update(value: value)
    }

    override func getAggregator() -> HistogramAggregator<T> {
        return histogramAggregator
    }
}

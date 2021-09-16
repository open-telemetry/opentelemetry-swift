/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class BoundHistogramMetricSdkBase<T>: BoundHistogramMetric<T> {
    override init(boundaries: Array<T>) {
        super.init(boundaries: boundaries)
    }

    func getAggregator() -> Aggregator<T> {
        fatalError()
    }
}

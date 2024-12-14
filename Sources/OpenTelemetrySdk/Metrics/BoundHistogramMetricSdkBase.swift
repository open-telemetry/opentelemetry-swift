/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class BoundHistogramMetricSdkBase<T>: BoundHistogramMetric<T> {
    override init(explicitBoundaries: [T]? = nil) {
        super.init(explicitBoundaries: explicitBoundaries)
    }

    func getAggregator() -> Aggregator<T> {
        fatalError()
    }
}

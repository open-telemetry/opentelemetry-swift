/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class BoundCounterMetricSdkBase<T>: BoundCounterMetric<T> {
    internal var status: RecordStatus
    internal let statusLock = Lock()

    init(recordStatus: RecordStatus) {
        status = recordStatus
        super.init()
    }

    func getAggregator() -> Aggregator<T> {
        fatalError()
    }
}

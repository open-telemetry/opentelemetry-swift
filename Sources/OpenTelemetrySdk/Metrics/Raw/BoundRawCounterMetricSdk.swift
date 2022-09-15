/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class BoundRawCounterMetricSdk<T: SignedNumeric> : BoundRawCounterMetricSdkBase<T> {
    var metricData = [MetricData]()
    var metricDataCheckpoint = [MetricData]()
    var lock = Lock()

    
    override init(recordStatus: RecordStatus) {
        super.init(recordStatus: recordStatus)
    }
    
    override func record(sum: T, startDate: Date, endDate: Date) {
        metricData.append(SumData<T>(startTimestamp: startDate, timestamp: endDate, sum: sum))
    }
    
    override func checkpoint() {
        lock.withLockVoid {
            metricDataCheckpoint = metricData
            metricData = [MetricData]()
        }
    }
    
    override func getMetrics() -> [MetricData] {
        return metricDataCheckpoint
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */


import Foundation


class BoundRawHistogramMetricSdk<T> : BoundRawHistogramMetricSdkBase<T> {
    var metricData = [MetricData]()
    var metricDataCheckpoint = [MetricData]()
    var lock = Lock()
    
    override init(recordStatus: RecordStatus) {
        super.init(recordStatus: recordStatus)
    }
    
    override func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T) {
        metricData.append(HistogramData<T>(startTimestamp: startDate, timestamp: endDate, buckets: (boundaries: explicitBoundaries,counts: counts), count: count, sum: sum))

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

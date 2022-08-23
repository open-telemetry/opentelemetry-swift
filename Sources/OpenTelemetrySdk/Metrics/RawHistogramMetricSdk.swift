/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi


internal class RawHistogramMetricSdk<T : SignedNumeric & Comparable> : RawHistogramMetric {

    
    var metricData = [MetricData]()
    var metricDataCheckpoint = [MetricData]()
    var lock = Lock()
    init() {
        
    
    }
    
    func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T) {
        metricData.append(HistogramData<T>(startTimestamp: startDate, timestamp: endDate, buckets: (boundaries: explicitBoundaries,counts: counts), count: count, sum: sum))
    }
    
    func checkpoint() {
        lock.withLockVoid {
            metricDataCheckpoint = metricData
            metricData = [MetricData]()
        }
    }
    
    func getMetrics() -> [MetricData] {
        return metricDataCheckpoint
    }
}

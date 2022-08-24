// Copyright © 2022 Elasticsearch BV
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

import Foundation
import OpenTelemetryApi

internal class RawCounterMetricSdk<T : SignedNumeric & Comparable> : RawCounterMetric {
    
    var metricData = [MetricData]()
    var metricDataCheckpoint = [MetricData]()
    
    var lock = Lock()
    
    func record(sum: T,  startDate: Date, endDate: Date) {
        lock.withLockVoid {
            metricData.append(SumData<T>(startTimestamp: startDate, timestamp: endDate, sum: sum))
        }
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

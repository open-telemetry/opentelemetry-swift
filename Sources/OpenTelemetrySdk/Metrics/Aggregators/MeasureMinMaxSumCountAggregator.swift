// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

public class MeasureMinMaxSumCountAggregator<T: SignedNumeric & Comparable>: Aggregator {
    fileprivate var summary = Summary<T>()
    fileprivate var pointCheck = Summary<T>()

    private let lock = Lock()

    func update(value: T) {
        lock.withLockVoid {
            self.summary.count += 1
            self.summary.sum += value
            self.summary.max = max(self.summary.max, value)
            self.summary.min = min(self.summary.min, value)
        }
    }

    func checkpoint() {
        summary = Summary<T>()
    }

    func toMetricData() -> MetricData {
        return SummaryData<T>(timestamp: Date(),
                              count: pointCheck.count,
                              sum: pointCheck.sum,
                              min: pointCheck.min,
                              max: pointCheck.max)
    }

    func getAggregationType() -> AggregationType {
        if T.self == Double.Type.self {
            return .doubleSummary
        } else {
            return .intSummary
        }
    }
}

private struct Summary<T> where T: SignedNumeric {
    var sum: T
    var count: Int
    var min: T
    var max: T
}

extension Summary where T: FloatingPoint {
    init() {
        sum = 0
        count = 0
        min = T.greatestFiniteMagnitude
        max = -T.greatestFiniteMagnitude
    }
}

extension Summary where T == Int {
    init() {
        sum = 0
        count = 0
        min = Int.max
        max = -Int.max
    }
}

extension Summary {
    init() {
        sum = 0
        count = 0
        min = 0
        max = 0
    }
}

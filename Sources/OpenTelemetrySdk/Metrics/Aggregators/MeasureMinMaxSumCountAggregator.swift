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

/// Aggregator which calculates summary (Min,Max,Sum,Count) from measures.
public class MeasureMinMaxSumCountAggregator<T: SignedNumeric & Comparable>: Aggregator<T> {
    fileprivate var summary = Summary<T>()
    fileprivate var pointCheck = Summary<T>()

    private let lock = Lock()

    override public func update(value: T) {
        lock.withLockVoid {
            self.summary.count += 1
            self.summary.sum += value
            self.summary.max = (self.summary.max != nil) ? max(self.summary.max, value) : value
            self.summary.min = (self.summary.min != nil) ? min(self.summary.min, value) : value
        }
    }

    override public func checkpoint() {
        lock.withLockVoid {
            super.checkpoint()
            pointCheck = summary
            summary = Summary<T>()
        }
    }

    public override func toMetricData() -> MetricData {
        return SummaryData<T>(startTimestamp: lastStart,
                              timestamp: lastEnd,
                              count: pointCheck.count,
                              sum: pointCheck.sum,
                              min: pointCheck.min ?? 0,
                              max: pointCheck.max ?? 0)
    }

    public override func getAggregationType() -> AggregationType {
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
    var min: T!
    var max: T!
    init() {
        sum = 0
        count = 0
    }
}

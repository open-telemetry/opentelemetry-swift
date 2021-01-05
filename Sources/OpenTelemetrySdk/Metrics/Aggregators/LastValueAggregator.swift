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

/// Simple aggregator that only keeps the last value.
public class LastValueAggregator<T: SignedNumeric>: Aggregator<T> {
    var value: T = 0
    var pointCheck: T = 0

    private let lock = Lock()

    public override func update(value: T) {
        lock.withLockVoid {
            self.value = value
        }
    }

    public override func checkpoint() {
        lock.withLockVoid {
            super.checkpoint()
            self.pointCheck = self.value
        }
    }

    public override func toMetricData() -> MetricData {
        return SumData<T>(startTimestamp: lastStart, timestamp: lastEnd, sum: pointCheck)
    }

    public override func getAggregationType() -> AggregationType {
        if T.self == Double.Type.self {
            return .doubleSum
        } else {
            return .intSum
        }
    }
}

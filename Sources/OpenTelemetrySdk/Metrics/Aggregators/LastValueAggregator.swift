/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

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

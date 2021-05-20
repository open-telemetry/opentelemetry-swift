/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Basic aggregator which calculates a Sum from individual measurements.
public class CounterSumAggregator<T: SignedNumeric>: Aggregator<T> {
    var sum: T = 0
    var pointCheck: T = 0
    private let lock = Lock()

    override public func update(value: T) {
        lock.withLockVoid {
            sum += value
        }
    }

    override public func checkpoint() {
        lock.withLockVoid {
            super.checkpoint()
            pointCheck = sum
            sum = 0
        }
    }

    public override func toMetricData() -> MetricData {
        return SumData<T>(startTimestamp: lastStart, timestamp: lastEnd , sum: pointCheck)
    }

    public override func getAggregationType() -> AggregationType {
        if T.self == Double.Type.self {
            return .doubleSum
        } else {
            return .intSum
        }
    }
}

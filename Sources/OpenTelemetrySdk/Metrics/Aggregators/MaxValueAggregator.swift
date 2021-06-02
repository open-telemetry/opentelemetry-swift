/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class MaxValueAggregator<T: SignedNumeric & Comparable>: Aggregator<T> {
    var value: T = 0
    var pointCheck: T = 0

    private let lock = Lock()

    override public func update(value: T) {
        lock.withLockVoid {
            if value > self.value {
                self.value = value
            }
        }
    }

    override public func checkpoint() {
        lock.withLockVoid {
            super.checkpoint()
            self.pointCheck = self.value
            self.value = 0
        }
    }

    override public func toMetricData() -> MetricData {
        return SumData<T>(startTimestamp: lastStart, timestamp: lastEnd, sum: pointCheck)
    }

    override public func getAggregationType() -> AggregationType {
        if T.self == Double.Type.self {
            return .doubleGauge
        } else {
            return .intGauge
        }
    }
}

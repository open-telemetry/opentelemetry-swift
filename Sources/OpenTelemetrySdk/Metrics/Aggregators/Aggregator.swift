/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class Aggregator<T> {
    var lastStart: Date = Date.distantFuture
    var lastEnd: Date = Date()

    public func update(value: T) {}
    public func checkpoint() {
        lastStart = lastEnd
        lastEnd = Date()
    }

    public func toMetricData() -> MetricData {
        return NoopMetricData()
    }

    public func getAggregationType() -> AggregationType {
        return .intSum
    }
}

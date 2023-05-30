/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
// Phase 2
//@available(*, deprecated, renamed: "StableMetricReader")
public protocol MetricProcessor {
    /// Finish the current collection cycle and return the metrics it holds.
    /// This is called at the end of one collection cycle by the Controller.
    /// MetricProcessor can use this to clear its Metrics (in case of stateless).
    /// - Returns: The list of metrics from this cycle, which are to be exported.
    func finishCollectionCycle() -> [Metric]
    
    /// Process the metric. This method is called once every collection interval.
    /// - Parameters:
    ///   - metric: the metric record.
    func process(metric: Metric)
}

struct NoopMetricProcessor: MetricProcessor {
    func finishCollectionCycle() -> [Metric] {
        return [Metric]()
    }

    func process(metric: Metric) {
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class MetricProcessorSdk: MetricProcessor {
    private let lock: Lock
    var metrics: [Metric]

    public init() {
        metrics = [Metric]()
        lock = Lock()
    }

    /// Finish the current collection cycle and return the metrics it holds.
    /// This is called at the end of one collection cycle by the Controller.
    /// MetricProcessor can use this to clear its Metrics (in case of stateless).
    /// - Returns: The list of metrics from this cycle, which are to be exported.
    public func finishCollectionCycle() -> [Metric] {
        lock.lock()
        defer {
            self.metrics = [Metric]()
            lock.unlock()
        }
        return metrics
    }

    /// Process the metric. This method is called once every collection interval.
    /// - Parameters:
    ///   - metric: the metric record.
    public func process(metric: Metric) {
        lock.lock()
        defer {
            lock.unlock()
        }

        metrics.append(metric)
    }
}

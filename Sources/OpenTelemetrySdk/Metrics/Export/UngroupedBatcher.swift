/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Batcher which retains all dimensions/labels.
public class UngroupedBatcher: MetricProcessor {
    public init() {}

    private var metrics = [Metric]()

    public func finishCollectionCycle() -> [Metric] {
        defer {
            self.metrics = [Metric]()
        }
        return metrics
    }

    public func process(metric: Metric) {
        metrics.append(metric)
    }
}

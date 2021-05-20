/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIOConcurrencyHelpers
import OpenTelemetrySdk

public class PrometheusExporter: MetricExporter {
    fileprivate let metricsLock = Lock()
    let options: PrometheusExporterOptions
    private var metrics = [Metric]()

    public init(options: PrometheusExporterOptions) {
        self.options = options
    }

    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        metricsLock.withLockVoid {
            self.metrics.append(contentsOf: metrics)
        }
        return .success
    }

    public func getAndClearMetrics() -> [Metric] {
        defer {
            metrics = [Metric]()
            metricsLock.unlock()
        }
        metricsLock.lock()
        return metrics
    }
}

public struct PrometheusExporterOptions {
    var url: String

    public init(url: String) {
        self.url = url
    }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class MeterSharedState {
    /// Configures metric processor. (aka batcher).
    var metricProcessor: MetricProcessor
    /// Sets the push interval.
    var metricPushInterval: TimeInterval
    /// Sets the exporter
    var metricExporter: MetricExporter

    var resource: Resource

    init(metricProcessor: MetricProcessor, metricPushInterval: TimeInterval, metricExporter: MetricExporter, resource: Resource) {
        self.metricProcessor = metricProcessor
        self.metricPushInterval = metricPushInterval
        self.metricExporter = metricExporter
        self.resource = resource
    }

    func addMetricExporter(metricExporter: MetricExporter) {
        if metricExporter is NoopMetricExporter {
            self.metricExporter = metricExporter
        } else if var multiMetricExporter = metricExporter as? MultiMetricExporter {
            multiMetricExporter.metricExporters.append(metricExporter)
        } else {
            self.metricExporter = MultiMetricExporter(metricExporters: [self.metricExporter, metricExporter])
        }
    }
}

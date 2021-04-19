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

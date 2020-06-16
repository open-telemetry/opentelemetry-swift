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

public struct MeterSharedState {
    /// Configures metric processor. (aka batcher).
    public private(set) var metricProcessor: MetricProcessor?
    /// Configures Metric Exporter.
    public private(set) var metricExporter: MetricExporter?
    /// Sets the push interval.
    public private(set) var metricPushInterval: TimeInterval?

    public init(metricProcessor: MetricProcessor? = nil, metricExporter: MetricExporter? = nil, metricPushInterval: TimeInterval? = nil) {
        self.metricProcessor = metricProcessor
        self.metricExporter = metricExporter
        self.metricPushInterval = metricPushInterval
    }
}

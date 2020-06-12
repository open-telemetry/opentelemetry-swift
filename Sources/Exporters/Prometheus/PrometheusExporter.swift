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

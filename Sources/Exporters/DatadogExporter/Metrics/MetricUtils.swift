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
import OpenTelemetrySdk

internal struct MetricUtils: Encodable {
    private static let gaugeType = "gauge"
    private static let countType = "count"

    /// getName converts the name adding a prefix if dessired
    static func getName(metric: Metric, configuration: ExporterConfiguration) -> String {
        if let prefix = configuration.metricsNamePrefix {
            return "\(prefix).\(metric.name)"
        } else {
            return "\(metric.name)"
        }
    }

    /// getType maps a metric into a Datadog type
    static func getType(metric: Metric) -> String {
        switch metric.aggregationType {
            case .doubleSum, .intSum:
                return countType
            case .doubleSummary, .intSummary:
                return gaugeType
        }
    }

    /// getTags maps a string dictionary into a slice of Datadog tags
    static func getTags(labels: [String: String]) -> [String] {
        var tags: [String] = []
        let defaultValue = "n/a"
        labels.forEach {
            tags.append("\($0.key):\($0.value.isEmpty ? defaultValue : $0.value)")
        }
        return tags
    }
}

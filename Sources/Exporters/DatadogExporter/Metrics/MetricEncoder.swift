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

internal struct DDMetricPoint {
    /// Log attributes received from the user. They are subject for sanitization.
    let timestamp: Date
    /// Log attributes added internally by the SDK. They are not a subject for sanitization.
    let value: Double
}

internal struct DDMetric: Encodable {
    var name: String
    var points: [DDMetricPoint]
    var type: String?
    var host: String?
    var interval: Int64?
    var tags: [String]

    func encode(to encoder: Encoder) throws {
        try MetricEncoder().encode(self, to: encoder)
    }
}

/// Encodes `DDMetric` to given encoder.
internal struct MetricEncoder {
    /// Coding keys for permanent `Metric` attributes.
    enum StaticCodingKeys: String, CodingKey {
        // MARK: - Attributes

        case name = "metric"
        case points
        case host
        case interval
        case tags
        case type
    }

    /// Coding keys for dynamic `Metric` attributes specified by user.
    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
        init(_ string: String) { self.stringValue = string }
    }

    func encode(_ metric: DDMetric, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StaticCodingKeys.self)
        try container.encode(metric.name, forKey: .name)
        var points = [[Double]]()
        metric.points.forEach {
            points.append([$0.timestamp.timeIntervalSince1970.rounded(), $0.value])
        }
        try container.encode(points, forKey: .points)

        if metric.type != nil {
            try container.encode(metric.type, forKey: .type)
        }
        if metric.host != nil {
            try container.encode(metric.host, forKey: .host)
        }
        if metric.interval != nil {
            try container.encode(metric.interval, forKey: .interval)
        }
        if !metric.tags.isEmpty {
            try container.encode(metric.tags, forKey: .tags)
        }
    }
}

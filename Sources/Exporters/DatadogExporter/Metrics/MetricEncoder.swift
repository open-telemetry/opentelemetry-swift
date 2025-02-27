/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct DDMetricPoint {
  /// Log attributes received from the user. They are subject for sanitization.
  let timestamp: Date
  /// Log attributes added internally by the SDK. They are not a subject for sanitization.
  let value: Double
}

struct DDMetric: Encodable {
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
struct MetricEncoder {
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
    init(_ string: String) { stringValue = string }
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

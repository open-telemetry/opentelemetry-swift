/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

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
    case .doubleSummary, .intSummary, .intGauge, .doubleGauge, .doubleHistogram, .intHistogram:
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

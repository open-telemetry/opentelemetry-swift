//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

@available(*, deprecated, renamed: "MetricExporter")
public typealias StableMetricExporter = MetricExporter

public protocol MetricExporter: AggregationTemporalitySelectorProtocol, DefaultAggregationSelector {
  func export(metrics: [MetricData]) -> ExportResult
  func flush() -> ExportResult
  func shutdown() -> ExportResult
}

public extension MetricExporter {
  func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
    return Aggregations.defaultAggregation()
  }
}

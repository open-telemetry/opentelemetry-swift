//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

@available(*, deprecated, renamed: "MetricExporter")
public typealias StableMetricExporter = MetricExporter

public protocol MetricExporter: AggregationTemporalitySelectorProtocol, DefaultAggregationSelector, Sendable {
  func export(metrics: [MetricData]) -> ExportResult
  func flush() -> ExportResult
  func shutdown() -> ExportResult

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func export(metrics: [MetricData]) async -> ExportResult

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func flush() async -> ExportResult

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func shutdown() async -> ExportResult
}

public extension MetricExporter {
  func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
    return Aggregations.defaultAggregation()
  }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension MetricExporter {
  func export(metrics: [MetricData]) async -> ExportResult {
    assertionFailure("async export(metrics:) must be implemented by \(type(of: self))")
    return .failure
  }

  func flush() async -> ExportResult {
    assertionFailure("async flush() must be implemented by \(type(of: self))")
    return .failure
  }

  func shutdown() async -> ExportResult {
    assertionFailure("async shutdown() must be implemented by \(type(of: self))")
    return .failure
  }
}

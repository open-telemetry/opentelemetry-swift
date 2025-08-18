/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public class StdoutMetricExporter: MetricExporter {
  let isDebug: Bool
  var aggregationTemporalitySelector: AggregationTemporalitySelector

  public init(isDebug: Bool, aggregationTemporalitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative()) {
    self.isDebug = isDebug
    self.aggregationTemporalitySelector = aggregationTemporalitySelector
  }

  public func export(metrics: [OpenTelemetrySdk.MetricData]) -> OpenTelemetrySdk.ExportResult {
    if isDebug {
      for metric in metrics {
        print(String(repeating: "-", count: 40))
        print("Name: \(metric.name)")
        print("Description: \(metric.description)")
        print("Unit: \(metric.unit)")
        print("IsMonotonic: \(metric.isMonotonic)")
        print("Resource: \(metric.resource)")
        print("InstrumentationScopeInfo: \(metric.instrumentationScopeInfo)")
        print("Type: \(metric.type)")
        print("AggregationTemporality: \(metric.data.aggregationTemporality)")
        if !metric.data.points.isEmpty {
          print("DataPoints:")
          for point in metric.data.points {
            print("  - StartEpochNanos: \(point.startEpochNanos)")
            print("    EndEpochNanos: \(point.endEpochNanos)")
            print("    Attributes: \(point.attributes)")
            print("    Exemplars:")
            for exemplar in point.exemplars {
              print("      - EpochNanos: \(exemplar.epochNanos)")
              if let ctx = exemplar.spanContext {
                print("        SpanContext: \(ctx)")
              }
              print("        FilteredAttributes: \(exemplar.filteredAttributes)")
              if let e = exemplar as? DoubleExemplarData {
                print("        Value: \(e.value)")
              }
              if let e = exemplar as? LongExemplarData {
                print("        Value: \(e.value)")
              }
            }
          }
        }
        print(String(repeating: "-", count: 40) + "\n")
      }
    } else {
      let jsonEncoder = JSONEncoder()
      for metric in metrics {
        do {
          let jsonData = try jsonEncoder.encode(metric)
          if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
          }
        } catch {
          print("Failed to serialize Metric as JSON: \(error)")
          return .failure
        }
      }
    }

    return .success
  }

  public func flush() -> OpenTelemetrySdk.ExportResult {
    return .success
  }

  public func shutdown() -> OpenTelemetrySdk.ExportResult {
    return .success
  }

  public func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    return aggregationTemporalitySelector.getAggregationTemporality(for: instrument)
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk

/// Small, self-contained telemetry values for exporter tests that need
/// something to export but do not care about its contents.
public enum TelemetryFixtures {
  public static func spanData(name: String = "span",
                              kind: SpanKind = .internal,
                              resource: Resource = Resource(),
                              attributes: [String: AttributeValue] = [:],
                              status: Status = .ok) -> SpanData {
    let start = Date()
    var data = SpanData(traceId: TraceId.random(),
                    spanId: SpanId.random(),
                    parentSpanId: nil,
                    resource: resource,
                    name: name,
                    kind: kind,
                    startTime: start,
                    attributes: attributes,
                    events: [SpanData.Event(name: "event", timestamp: start)],
                    status: status,
                    endTime: start.addingTimeInterval(0.001))
    // Exporters derive dropped counts from these totals; keep them consistent.
    data.settingTotalRecordedEvents(1)
    data.settingTotalAttributeCount(attributes.count)
    return data
  }

  public static func logRecord(body: String = "hello",
                               attributes: [String: AttributeValue] = [:]) -> ReadableLogRecord {
    let context = SpanContext.create(traceId: TraceId.random(),
                                     spanId: SpanId.random(),
                                     traceFlags: TraceFlags(),
                                     traceState: TraceState())
    return ReadableLogRecord(resource: Resource(),
                             instrumentationScopeInfo: InstrumentationScopeInfo(name: "fixture"),
                             timestamp: Date(),
                             observedTimestamp: Date(),
                             spanContext: context,
                             severity: .info,
                             body: .string(body),
                             attributes: attributes)
  }

  public static func metricData(name: String = "metric", value: Double = 1) -> MetricData {
    let point = DoublePointData(startEpochNanos: 0,
                                endEpochNanos: 1,
                                attributes: [:],
                                exemplars: [],
                                value: value)
    return MetricData(resource: Resource(),
                      instrumentationScopeInfo: InstrumentationScopeInfo(name: "fixture"),
                      name: name,
                      description: "fixture metric",
                      unit: "",
                      type: .DoubleSum,
                      isMonotonic: true,
                      data: MetricData.Data(aggregationTemporality: .cumulative, points: [point]))
  }
}

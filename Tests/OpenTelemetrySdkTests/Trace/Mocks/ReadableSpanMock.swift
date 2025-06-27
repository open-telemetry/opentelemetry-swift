/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk

class ReadableSpanMock: ReadableSpan {
  var hasEnded: Bool = false
  var latency: TimeInterval = 0

  var kind: SpanKind {
    return .client
  }

  var instrumentationScopeInfo = InstrumentationScopeInfo()

  var name: String = "ReadableSpanMock"

  var forcedReturnSpanContext: SpanContext?
  var forcedReturnSpanData: SpanData?

  func end() {
    OpenTelemetry.instance.contextProvider.removeContextForSpan(self)
  }

  func end(time: Date) { end() }

  func toSpanData() -> SpanData {
    return forcedReturnSpanData ?? SpanData(traceId: context.traceId,
                                            spanId: context.spanId,
                                            traceFlags: context.traceFlags,
                                            traceState: TraceState(),
                                            resource: Resource(attributes: [String: AttributeValue]()),
                                            instrumentationScope: InstrumentationScopeInfo(),
                                            name: "ReadableSpanMock",
                                            kind: .client,
                                            startTime: Date(timeIntervalSinceReferenceDate: 0),
                                            endTime: Date(timeIntervalSinceReferenceDate: 0),
                                            hasRemoteParent: false)
  }

  var context: SpanContext {
    forcedReturnSpanContext ?? SpanContext.create(traceId: TraceId.random(), spanId: SpanId.random(), traceFlags: TraceFlags(), traceState: TraceState())
  }

  var isRecording: Bool = false

  var status: Status = .unset

  func updateName(name: String) {}

  func setAttribute(key: String, value: AttributeValue?) {}

  func getAttributes() -> [String : OpenTelemetryApi.AttributeValue] {
    return [:]
  }

  func setAttributes(_ attributes: [String : OpenTelemetryApi.AttributeValue]) {}

  func addEvent(name: String) {}

  func addEvent(name: String, attributes: [String: AttributeValue]) {}

  func addEvent(name: String, timestamp: Date) {}

  func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}

  func recordException(_ exception: SpanException) {}

  func recordException(_ exception: any SpanException, timestamp: Date) {}

  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue]) {}

  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue], timestamp: Date) {}

  var description: String = "ReadableSpanMock"
}

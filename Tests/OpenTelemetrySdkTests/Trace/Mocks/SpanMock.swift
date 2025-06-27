/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

class SpanMock: Span {

  var name: String = ""

  var kind: SpanKind {
    return .client
  }

  var context = SpanContext.create(traceId: TraceId.random(), spanId: SpanId.random(), traceFlags: TraceFlags(), traceState: TraceState())

  var isRecording: Bool = false

  var status: Status = .unset

  func end() {
    OpenTelemetry.instance.contextProvider.removeContextForSpan(self)
  }

  func end(time: Date) { end() }

  func updateName(name: String) {}

  func setAttribute(key: String, value: AttributeValue?) {}

  func setAttributes(_ attributes: [String : OpenTelemetryApi.AttributeValue]) {}

  func addEvent(name: String) {}

  func addEvent(name: String, attributes: [String: AttributeValue]) {}

  func addEvent(name: String, timestamp: Date) {}

  func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}

  func recordException(_ exception: SpanException) {}

  func recordException(_ exception: any SpanException, timestamp: Date) {}

  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue]) {}

  func recordException(_ exception: any SpanException, attributes: [String: AttributeValue], timestamp: Date) {}

  var description: String = "SpanMock"
}

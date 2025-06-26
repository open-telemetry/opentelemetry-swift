/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class LoggingSpan: Span {
  var name: String
  var kind: SpanKind
  var context: SpanContext
  var isRecording: Bool = true
  var status: Status = .unset

  public init(name: String, kind: SpanKind) {
    self.name = name
    self.kind = kind
    context = SpanContext.create(traceId: TraceId.random(),
                                 spanId: SpanId.random(),
                                 traceFlags: TraceFlags(),
                                 traceState: TraceState())
  }

  public var description: String {
    return name
  }

  public func updateName(name: String) {
    Logger.log("Span.updateName(\(name))")
    self.name = name
  }

  public func setAttribute(key: String, value: String) {
    Logger.log("Span.setAttribute(key: \(key), value: \(value))")
  }

  public func setAttribute(key: String, value: Int) {
    Logger.log("Span.setAttribute(key: \(key), value: \(value))")
  }

  public func setAttribute(key: String, value: Double) {
    Logger.log("Span.setAttribute(key: \(key), value: \(value))")
  }

  public func setAttribute(key: String, value: Bool) {
    Logger.log("Span.setAttribute(key: \(key), value: \(value))")
  }

  public func setAttribute(key: String, value: AttributeValue?) {
    Logger.log("Span.setAttribute(key: \(key), value: \(String(describing: value)))")
  }

  public func setAttribute(keyValuePair: (String, AttributeValue)) {
    Logger.log("Span.SetAttributes(keyValue: \(keyValuePair))")
    setAttribute(key: keyValuePair.0, value: keyValuePair.1)
  }

  public func setAttributes(
    _ attributes: [String: OpenTelemetryApi.AttributeValue]
  ) {
    attributes.forEach { key, value in
      setAttribute(key: key, value: value)
    }
  }

  public func addEvent(name: String) {
    Logger.log("Span.addEvent(\(name))")
  }

  public func addEvent(name: String, timestamp: Date) {
    Logger.log("Span.addEvent(\(name) timestamp:\(timestamp))")
  }

  public func addEvent(name: String, attributes: [String: AttributeValue]) {
    Logger.log("Span.addEvent(\(name), attributes:\(attributes) )")
  }

  public func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
    Logger.log("Span.addEvent(\(name), attributes:\(attributes), timestamp:\(timestamp))")
  }

  public func recordException(_ exception: SpanException) {
    Logger.log("Span.recordException(\(exception)")
  }

  public func recordException(_ exception: SpanException, timestamp: Date) {
    Logger.log("Span.recordException(\(exception), timestamp:\(timestamp))")
  }

  public func recordException(_ exception: SpanException, attributes: [String: AttributeValue]) {
    Logger.log("Span.recordException(\(exception), attributes:\(attributes)")
  }

  public func recordException(_ exception: SpanException, attributes: [String: AttributeValue], timestamp: Date) {
    Logger.log("Span.recordException(\(exception), attributes:\(attributes), timestamp:\(timestamp))")
  }

  public func end() {
    Logger.log("Span.End, Name: \(name)")
  }

  public func end(time: Date) {
    Logger.log("Span.End, Name: \(name), time:\(time)) }")
  }
}

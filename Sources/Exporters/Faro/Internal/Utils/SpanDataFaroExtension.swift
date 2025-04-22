/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// Extension on SpanData to provide conversion to Faro events and attributes
extension SpanData {
  /// Creates a Faro event name from the span name
  /// - Returns: A string formatted as 'faro.tracing.{spanName}'
  func getFaroEventName() -> String {
    // Check for HTTP semantic attributes to determine if it's an HTTP span
    if attributes["http.scheme"] != nil || attributes["http.method"] != nil {
      return "faro.tracing.fetch"
    } else {
      // Use the original span name prefixed with "span." for non-HTTP spans
      return "span.\(name)"
    }
  }

  /// Extracts relevant attributes from the span for a Faro event
  /// - Returns: A dictionary of string attributes for the Faro event
  func getFaroEventAttributes() -> [String: String] {
    var faroEventAttributes: [String: String] = [:]

    // Calculate duration in milliseconds from startTime and endTime
    let durationMs = endTime.timeIntervalSince(startTime) * 1000

    faroEventAttributes["name"] = name
    faroEventAttributes["status"] = status.description
    faroEventAttributes["duration_ms"] = String(format: "%.3f", durationMs)
    faroEventAttributes["has_parent"] = parentSpanId != nil ? "true" : "false"

    // Convert all span attributes to strings, similar to Flutter implementation
    for (key, value) in attributes {
      faroEventAttributes[key] = String(describing: value)
    }

    return faroEventAttributes
  }

  /// Creates a Faro trace context from the span
  /// - Returns: A FaroTraceContext object containing trace and span IDs
  func getFaroTraceContext() -> FaroTraceContext? {
    return FaroTraceContext.create(traceId: traceId.hexString, spanId: spanId.hexString)
  }
}

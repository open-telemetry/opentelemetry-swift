/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryApi

/// Extends the standard SpanAdapter to add session IDs to spans for Faro
enum FaroSpanAdapter {
  /// Converts SpanData list to protocol buffer ResourceSpans with session IDs
  /// - Parameters:
  ///   - spanDataList: List of spans to convert
  ///   - sessionId: The session ID to add to spans
  /// - Returns: Protocol buffer ResourceSpans list
  static func toProtoResourceSpans(spanDataList: [SpanData], sessionId: String) -> [Opentelemetry_Proto_Trace_V1_ResourceSpans] {
    // If no spans, return empty result
    if spanDataList.isEmpty {
      return []
    }
    
    // Create enriched spans with session ID attributes
    let enrichedSpans = spanDataList.map { span -> SpanData in
      // Create a copy of the existing attributes and add session IDs
      var updatedAttributes = span.attributes
      
      // Add session ID attributes
      updatedAttributes["session_id"] = AttributeValue.string(sessionId)
      updatedAttributes["session.id"] = AttributeValue.string(sessionId)

      // Create a new span with updated attributes
      var mutableSpan = span
      mutableSpan = mutableSpan.settingAttributes(updatedAttributes)
      mutableSpan = mutableSpan.settingTotalAttributeCount(span.totalAttributeCount+2)
      return mutableSpan
    }
    
    // Use the standard SpanAdapter to convert the enriched spans
    let result = SpanAdapter.toProtoResourceSpans(spanDataList: enrichedSpans)
    return result
  }
} 
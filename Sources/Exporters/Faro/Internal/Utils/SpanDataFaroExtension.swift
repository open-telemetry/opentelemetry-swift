/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Extension on SpanData to provide conversion to Faro events and attributes
extension SpanData {
    /// Creates a Faro event name from the span name
    /// - Returns: A string formatted as 'faro.tracing.{spanName}'
    func getFaroEventName() -> String {
        return "faro.tracing.\(name)"
    }
    
    /// Extracts relevant attributes from the span for a Faro event
    /// - Returns: A dictionary of string attributes for the Faro event
    func getFaroEventAttributes() -> [String: String] {
        var faroEventAttributes: [String: String] = [:]
        
        // Convert all span attributes to strings, similar to Flutter implementation
        for (key, value) in self.attributes {
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
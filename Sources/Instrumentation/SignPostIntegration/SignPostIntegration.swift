/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(watchOS)

import Foundation
import os
import OpenTelemetryApi
import OpenTelemetrySdk

/// A span processor that decorates spans with the origin attribute
@available(macOS 10.14, iOS 12.0, tvOS 12.0, *)
public class SignPostIntegration: SpanProcessor {
  
  public let isStartRequired = true
  public let isEndRequired = true
  public let osLog = OSLog(subsystem: "OpenTelemetry", category: .pointsOfInterest)
  
  public init() {}
  
  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let signpostID = OSSignpostID(log: osLog, object: self)
    os_signpost(.begin, log: osLog, name: "Span", signpostID: signpostID, "%{public}@", span.name)
  }
  
  public func onEnd(span: ReadableSpan) {
    let signpostID = OSSignpostID(log: osLog, object: self)
    os_signpost(.end, log: osLog, name: "Span", signpostID: signpostID)
  }
  
  public func forceFlush(timeout: TimeInterval? = nil) {}
  public func shutdown(explicitTimeout: TimeInterval?) {
  }
}

#endif

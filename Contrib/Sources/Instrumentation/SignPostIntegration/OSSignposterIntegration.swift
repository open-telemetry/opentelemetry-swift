/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import os
import OpenTelemetryApi
import OpenTelemetrySdk

/// A span processor that decorates spans with the origin attribute
@available(iOS 15.0, macOS 12, tvOS 15.0, watchOS 8.0, *)
public class OSSignposterIntegration: SpanProcessor {

  public let isStartRequired = true
  public let isEndRequired = true
  public let osSignposter = OSSignposter(subsystem: "OpenTelemetry", category: .pointsOfInterest)
  public let ossignposterQueue = DispatchQueue(label: "org.opentelemetry.ossignposterIntegration")
  private var spanIdToStateMap: [String: OSSignpostIntervalState] = [:]

  public init() {}

  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let state = osSignposter.beginInterval("Span", id: .exclusive, "\(span.name, privacy: .public)")
    ossignposterQueue.sync {
      spanIdToStateMap[span.context.spanId.hexString] = state
    }
  }

  public func onEnd(span: ReadableSpan) {
    let state = ossignposterQueue.sync {
      spanIdToStateMap.removeValue(forKey: span.context.spanId.hexString)
    }
    if let state {
      osSignposter.endInterval("Span", state)
    }
  }

  public func forceFlush(timeout: TimeInterval? = nil) {}
  public func shutdown(explicitTimeout: TimeInterval?) {}

}

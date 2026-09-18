/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import os
import OpenTelemetryApi
import OpenTelemetrySdk

/// A span processor that emits signpost intervals for spans.
@available(iOS 15.0, macOS 12, tvOS 15.0, watchOS 8.0, *)
public class OSSignposterIntegration: SpanProcessor {
  public let isStartRequired = true
  public let isEndRequired = true
  public let osSignposter: OSSignposter
  public let ossignposterQueue = DispatchQueue(label: "org.opentelemetry.ossignposterIntegration")
  private var spanIdToStateMap: [String: OSSignpostIntervalState] = [:]

  public init() {
    osSignposter = OSSignposter(subsystem: "OpenTelemetry", category: .pointsOfInterest)
  }

  /// Creates a processor that emits signposts to the supplied log.
  public init(log: OSLog) {
    osSignposter = OSSignposter(logHandle: log)
  }

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

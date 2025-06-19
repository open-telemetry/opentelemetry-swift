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
  @available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public class OSSignposterIntegration: SpanProcessor {

    private static var osSignpostStateKey: UInt8 = 0

    public let isStartRequired = true
    public let isEndRequired = true
    public let osSignposter = OSSignposter(subsystem: "OpenTelemetry", category: .pointsOfInterest)

    public init() {}

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
      let signpostID = osSignposter.makeSignpostID()
      let osSignpostState = osSignposter.beginInterval("Span", id: signpostID, "\(span.name, privacy: .public)")
      objc_setAssociatedObject(span, &OSSignposterIntegration.osSignpostStateKey, osSignpostState, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    public func onEnd(span: ReadableSpan) {
      if let state = objc_getAssociatedObject(span, &OSSignposterIntegration.osSignpostStateKey) as? OSSignpostIntervalState {
        osSignposter.endInterval("Span", state)
        objc_setAssociatedObject(span, &OSSignposterIntegration.osSignpostStateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
    }

    public func forceFlush(timeout: TimeInterval? = nil) {}
    public func shutdown(explicitTimeout: TimeInterval?) {}
  }
#endif

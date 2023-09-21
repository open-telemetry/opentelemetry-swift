/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// SpanProcessor is the interface TracerSdk uses to allow synchronous hooks for when a Span
/// is started or when a Span is ended.
public protocol SpanProcessor {
  /// Is true if this  SpanProcessor requires start events.
  var isStartRequired: Bool { get }
  
  /// Returns true if this  SpanProcessor requires end events.
  var isEndRequired: Bool { get }
  
  /// Called when a Span is started, if the Span.isRecording is true.
  /// This method is called synchronously on the execution thread, should not throw or block the
  /// execution thread.
  /// - Parameter parentContext: the context of the span parent, if exists
  /// - Parameter span: the ReadableSpan that just started
  func onStart(parentContext: SpanContext?, span: ReadableSpan)
  
  /// Called when a Span is ended, if the Span.isRecording() is true.
  /// This method is called synchronously on the execution thread, should not throw or block the
  /// execution thread.
  /// - Parameter span: the ReadableSpan that just ended.
  mutating func onEnd(span: ReadableSpan)
  
  /// Called when TracerSdk.shutdown() is called.
  /// Implementations must ensure that all span events are processed before returning
  mutating func shutdown(explicitTimeout: TimeInterval?)
  
  /// Processes all span events that have not yet been processed.
  /// This method is executed synchronously on the calling thread
  /// - Parameter timeout: Maximum time the flush complete or abort. If nil, it will wait indefinitely
  func forceFlush(timeout: TimeInterval?)
}

extension SpanProcessor {
  func forceFlush() {
    return forceFlush(timeout: nil)
  }
  mutating func shutdown() {
    return shutdown(explicitTimeout: nil)
  }
}


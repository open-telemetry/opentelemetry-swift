/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

/// OpenTelemetry span processor that automatically adds session ID to all spans
/// This processor ensures that all telemetry data is associated with the current session
public class SessionSpanProcessor: SpanProcessor {
  /// Indicates that this processor needs to be called when spans start
  public var isStartRequired = true
  /// Indicates that this processor doesn't need to be called when spans end
  public var isEndRequired: Bool = false
  /// Reference to the session manager for retrieving current session ID
  private var sessionManager: SessionManager

  /// Initializes the span processor with a session manager
  /// - Parameter sessionManager: The session manager to use for retrieving session IDs (defaults to singleton)
  public init(sessionManager: SessionManager? = nil) {
    self.sessionManager = sessionManager ?? SessionManagerProvider.getInstance()
  }

  /// Called when a span starts - adds the current session ID as an attribute
  /// - Parameters:
  ///   - parentContext: The parent span context (unused)
  ///   - span: The span being started
  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let session = sessionManager.getSession()
    span.setAttribute(key: SessionConstants.id, value: session.id)
    if session.previousId != nil {
      span.setAttribute(key: SessionConstants.previousId, value: session.previousId!)
    }
  }

  /// Called when a span ends - no action needed for session tracking
  /// - Parameter span: The span being ended
  public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
    // No action needed
  }

  /// Shuts down the processor - no cleanup needed
  /// - Parameter explicitTimeout: Timeout for shutdown (unused)
  public func shutdown(explicitTimeout: TimeInterval?) {
    // No cleanup needed
  }

  /// Forces a flush of any pending data - no action needed
  /// - Parameter timeout: Timeout for flush (unused)
  public func forceFlush(timeout: TimeInterval?) {
    // No action needed
  }
}
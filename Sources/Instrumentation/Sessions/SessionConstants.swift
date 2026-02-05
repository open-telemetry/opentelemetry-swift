/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

/// Constants for OpenTelemetry session instrumentation.
///
/// Provides standardized attribute names and event types following OpenTelemetry
/// semantic conventions for session tracking.
///
/// Reference: https://opentelemetry.io/docs/specs/semconv/general/session/

import Foundation

public class SessionConstants {
  // MARK: - OpenTelemetry Semantic Conventions
  
  /// Event name for session start events
  public static let sessionStartEvent = "session.start"
  /// Event name for session end events
  public static let sessionEndEvent = "session.end"
  
  /// Notification name for session events
  public static let sessionEventNotification = "SessionEventInstrumentation.SessionEvent"
}

let SessionEventNotification = Notification.Name(SessionConstants.sessionEventNotification)
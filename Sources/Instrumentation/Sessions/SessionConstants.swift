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
public class SessionConstants {
  // MARK: - OpenTelemetry Semantic Conventions
  
  /// Event name for session start events
  public static let sessionStartEvent = "session.start"
  /// Event name for session end events  
  public static let sessionEndEvent = "session.end"
  /// Attribute name for session identifier
  public static let id = "session.id"
  /// Attribute name for previous session identifier
  public static let previousId = "session.previous_id"

  // MARK: - Extension Attributes
  
  /// Attribute name for session start timestamp
  public static let startTime = "session.start_time"
  /// Attribute name for session end timestamp
  public static let endTime = "session.end_time"
  /// Attribute name for session duration
  public static let duration = "session.duration"

  // MARK: - Internal Constants
  
  /// Notification name for session events
  public static let sessionEventNotification = "SessionEventInstrumentation.SessionEvent"
}
/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Enum to specify the type of session event
public enum SessionEventType {
  case start
  case end
}

/// Represents a session event with its associated session and event type
public struct SessionEvent {
  let session: Session
  let eventType: SessionEventType
}

/// Instrumentation for tracking and logging session lifecycle events.
///
/// This class is responsible for creating OpenTelemetry log records for session start and end events.
/// It handles sessions that are created both before and after the instrumentation is initialized by
/// using a queue mechanism and notification system.
///
/// The instrumentation follows these key patterns:
/// - Sessions created before instrumentation is applied are stored in a static queue
/// - Sessions created after instrumentation is applied trigger notifications
/// - All session events are converted to OpenTelemetry log records with appropriate attributes
/// - Session end events include duration and end time attributes
public class SessionEventInstrumentation {
  private static var logger: Logger {
    return OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: SessionEventInstrumentation.instrumentationKey)
  }

  /// Queue for storing session events that were created before instrumentation was initialized.
  /// This allows capturing session events that occur during application startup before
  /// the OpenTelemetry SDK is fully initialized.
  /// Limited to 20 items to prevent memory issues.
  static var queue: [SessionEvent] = []

  /// Maximum number of sessions that can be queued before instrumentation is applied
  static let maxQueueSize: UInt8 = 32

  /// Notification name for new session events.
  /// Used to broadcast session creation and expiration events after instrumentation is applied.
  @available(*, deprecated, message: "Use SessionEventNotification instead")
  static let sessionEventNotification = SessionEventNotification

  static let instrumentationKey = "io.opentelemetry.sessions"

  @available(*, deprecated, message: "Use SessionEventInstrumentation.install() instead")
  public init() {
    SessionEventInstrumentation.install()
  }

  /// Flag to track if the instrumentation has been applied.
  /// Controls whether new sessions are queued or immediately processed via notifications.
  static var isApplied = false
  public static func install() {
    guard !isApplied else {
      return
    }

    isApplied = true
    // Process any queued sessions
    processQueuedSessions()
  }

  /// Process any sessions that were queued before instrumentation was applied.
  ///
  /// This method is called during the `apply()` process to handle any sessions that
  /// were created before the instrumentation was initialized. It creates log records
  /// for all queued sessions and then clears the queue.
  private static func processQueuedSessions() {
    let sessionEvents = SessionEventInstrumentation.queue

    if sessionEvents.isEmpty {
      return
    }

    for sessionEvent in sessionEvents {
      createSessionEvent(session: sessionEvent.session, eventType: sessionEvent.eventType)
    }

    SessionEventInstrumentation.queue.removeAll()
  }

  /// Create session start or end log record based on the specified event type.
  ///
  /// - Parameters:
  ///   - session: The session to create an event for
  ///   - eventType: The type of event to create (start or end)
  private static func createSessionEvent(session: Session, eventType: SessionEventType) {
    switch eventType {
    case .start:
      createSessionStartEvent(session: session)
    case .end:
      createSessionEndEvent(session: session)
    }
  }

  /// Create a log record for a `session.start` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// and previous session ID (if available).
  /// - Parameter session: The session that has started
  private static func createSessionStartEvent(session: Session) {
    var attributes: [String: AttributeValue] = [
      SemanticConventions.Session.id.rawValue: AttributeValue.string(session.id)
    ]

    if let previousId = session.previousId {
      attributes[SemanticConventions.Session.previousId.rawValue] = AttributeValue.string(previousId)
    }

    /// Create `session.start` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setEventName(SessionConstants.sessionStartEvent)
      .setAttributes(attributes)
      .setTimestamp(session.startTime)
      .emit()
  }

  /// Create a log record for a `session.end` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// end time, duration, and previous session ID (if available).
  /// - Parameter session: The expired session
  private static func createSessionEndEvent(session: Session) {
    guard let endTime = session.endTime,
    let duration = session.duration else {
      return
    }

    var attributes: [String: AttributeValue] = [
      SemanticConventions.Session.id.rawValue: AttributeValue.string(session.id),
      SessionConstants.duration: AttributeValue.double(Double(duration.toNanoseconds))
    ]

    if let previousId = session.previousId {
      attributes[SemanticConventions.Session.previousId.rawValue] = AttributeValue.string(previousId)
    }

    /// Create `session.end`` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setEventName(SessionConstants.sessionEndEvent)
      .setAttributes(attributes)
      .setTimestamp(endTime)
      .emit()
  }

  /// Add a session to the queue or send notification if instrumentation is already applied.
  ///
  /// This static method is the main entry point for handling new sessions. It either:
  /// - Adds the session to the static queue if instrumentation hasn't been applied yet (max 10 items)
  /// - Posts a notification with the session if instrumentation has been applied
  ///
  /// - Parameter session: The session to process
  static func addSession(session: Session, eventType: SessionEventType) {
    if isApplied {
      createSessionEvent(session: session, eventType: eventType)
    } else {
      /// SessionManager creates sessions before SessionEventInstrumentation is applied,
      /// which the notification observer cannot see. So we need to keep the sessions in a queue.
      if queue.count >= maxQueueSize {
        return
      }
      queue.append(SessionEvent(session: session, eventType: eventType))
    }
  }
}

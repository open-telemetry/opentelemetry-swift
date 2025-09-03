/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

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
  private let logger: Logger

  /// Queue for storing sessions that were created before instrumentation was initialized.
  /// This allows capturing session events that occur during application startup before
  /// the OpenTelemetry SDK is fully initialized.
  internal static var queue: [Session] = []

  /// Notification name for new session events.
  /// Used to broadcast session creation and expiration events after instrumentation is applied.
  static let sessionEventNotification = Notification.Name(SessionConstants.sessionEventNotification)

  static let instrumentationKey = "io.opentelemetry.sessions"

  /// Flag to track if the instrumentation has been applied.
  /// Controls whether new sessions are queued or immediately processed via notifications.
  public internal(set) static var isApplied = false

  public init() {
    self.logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: SessionEventInstrumentation.instrumentationKey)
    
    guard !SessionEventInstrumentation.isApplied else {
      return
    }

    SessionEventInstrumentation.isApplied = true
    // Process any queued sessions
    processQueuedSessions()

    // Start observing for new session notifications
    NotificationCenter.default.addObserver(
      forName: SessionEventInstrumentation.sessionEventNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let session = notification.object as? Session {
        self.createSessionEvent(session: session)
      }
    }
  }

  /// Process any sessions that were queued before instrumentation was applied.
  ///
  /// This method is called during the `apply()` process to handle any sessions that
  /// were created before the instrumentation was initialized. It creates log records
  /// for all queued sessions and then clears the queue.
  private func processQueuedSessions() {
    let sessions = SessionEventInstrumentation.queue

    if sessions.isEmpty {
      return
    }

    for session in sessions {
      createSessionEvent(session: session)
    }

    SessionEventInstrumentation.queue.removeAll()
  }

  /// Create session start or end log record, depending on if the session is expired.
  ///
  /// This method routes the session to the appropriate handler based on its expiration status.
  /// - Parameter session: The session to create an event for
  private func createSessionEvent(session: Session) {
    if session.isExpired() {
      createSessionEndEvent(session: session)
    } else {
      createSessionStartEvent(session: session)
    }
  }

  /// Create a log record for a `session.start` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// and previous session ID (if available).
  /// - Parameter session: The session that has started
  private func createSessionStartEvent(session: Session) {
    var attributes: [String: AttributeValue] = [
      SessionConstants.id: AttributeValue.string(session.id),
      SessionConstants.startTime: AttributeValue.double(session.startTime.timeIntervalSince1970)
    ]

    if let previousId = session.previousId {
      attributes[SessionConstants.previousId] = AttributeValue.string(previousId)
    }

    /// Create `session.start` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setBody(AttributeValue.string(SessionConstants.sessionStartEvent))
      .setAttributes(attributes)
      .emit()
  }

  /// Create a log record for a `session.end` event.
  ///
  /// Creates an OpenTelemetry log record with session attributes including ID, start time,
  /// end time, duration, and previous session ID (if available).
  /// - Parameter session: The expired session
  private func createSessionEndEvent(session: Session) {
    guard session.isExpired(),
          let endTime = session.endTime,
          let duration = session.duration else {
      return
    }

    var attributes: [String: AttributeValue] = [
      SessionConstants.id: AttributeValue.string(session.id),
      SessionConstants.startTime: AttributeValue.double(session.startTime.timeIntervalSince1970),
      SessionConstants.endTime: AttributeValue.double(endTime.timeIntervalSince1970),
      SessionConstants.duration: AttributeValue.double(duration)
    ]

    if let previousId = session.previousId {
      attributes[SessionConstants.previousId] = AttributeValue.string(previousId)
    }

    /// Create `session.end`` log record according to otel semantic convention
    /// https://opentelemetry.io/docs/specs/semconv/general/session/
    logger.logRecordBuilder()
      .setBody(AttributeValue.string(SessionConstants.sessionEndEvent))
      .setAttributes(attributes)
      .emit()
  }

  /// Add a session to the queue or send notification if instrumentation is already applied.
  ///
  /// This static method is the main entry point for handling new sessions. It either:
  /// - Adds the session to the static queue if instrumentation hasn't been applied yet
  /// - Posts a notification with the session if instrumentation has been applied
  ///
  /// - Parameter session: The session to process
  static func addSession(session: Session) {
    if isApplied {
      NotificationCenter.default.post(
        name: sessionEventNotification,
        object: session
      )
    } else {
      /// SessionManager creates sessions before SessionEventInstrumentation is applied,
      /// which the notification observer cannot see. So we need to keep the sessions in a queue.
      queue.append(session)
    }
  }
}
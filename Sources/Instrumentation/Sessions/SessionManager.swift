/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Manages OpenTelemetry sessions with automatic expiration and persistence.
/// Provides thread-safe access to session information and handles session lifecycle.
/// Sessions are automatically extended on access and persisted to UserDefaults.
public class SessionManager {
  private var configuration: SessionConfig
  private var _session: Session?

  private var session: Session? {
    get {
      return sessionQueue.sync { _session }
    }
    set {
      sessionQueue.sync { _session = newValue }
    }
  }

  private let sessionQueue = DispatchQueue(
    label: "io.opentelemetry.SessionManager",
    qos: .userInitiated // increase priority because session are synchronously fetched
  )

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter configuration: Session configuration settings
  public init(configuration: SessionConfig = .default) {
    self.configuration = configuration
    restoreSessionFromDisk()
  }

  /// Gets the current session, creating or extending it as needed
  /// This method is thread-safe and will extend the session expireTime time
  /// - Returns: The current active session
  @discardableResult
  public func getSession() -> Session {
    refreshSession()
    return session!
  }

  /// Gets the current session without extending its expireTime time
  /// - Returns: The current session if one exists, nil otherwise
  public func peekSession() -> Session? {
    return session
  }

  /// Creates a new session with a unique identifier
  private func startSession() {
    let now = Date()
    let previousId = session?.id
    let newId = UUID().uuidString

    let previousSession = session

    // Create new session
    session = Session(
      id: newId,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: previousId,
      startTime: now,
      sessionTimeout: configuration.sessionTimeout
    )

    /// Queue the previous session for a `session.end` event
    if let previousSession {
      SessionEventInstrumentation.addSession(session: previousSession, eventType: .end)
    }

    // Queue the new session for a `session.start`` event
    SessionEventInstrumentation.addSession(session: session!, eventType: .start)

    // Post notification for session start
    if let session {
      NotificationCenter.default.post(name: SessionEventNotification, object: session)
    }
  }

  /// Refreshes the current session, creating new one if expired or extending existing one
  private func refreshSession() {
    if session == nil || session!.isExpired() {
      startSession()
    } else {
      // Otherwise, extend the existing session but preserve the startTime
      session = Session(
        id: session!.id,
        expireTime: Date(timeIntervalSinceNow: Double(configuration.sessionTimeout)),
        previousId: session!.previousId,
        startTime: session!.startTime,
        sessionTimeout: configuration.sessionTimeout
      )
    }
    saveSessionToDisk()
  }

  /// Schedules the current session to be persisted to UserDefaults
  private func saveSessionToDisk() {
    if session != nil {
      SessionStore.scheduleSave(session: session!)
    }
  }

  /// Restores a previously saved session from UserDefaults
  private func restoreSessionFromDisk() {
    session = SessionStore.load()
  }
}

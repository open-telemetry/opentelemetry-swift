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
  private var session: Session?
  private let lock = NSLock()

  private struct SessionTransition {
    let current: Session
    let previous: Session?
  }

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
    let transition : SessionTransition? = lock.withLock {
      if session == nil || session!.isExpired() {
        return startSession()
      }
      refreshSession()
      return nil
    }
    
    // Call external code outside the lock only if new session was created
    if let transition {
      if let previousSession = transition.previous {
        SessionEventInstrumentation.addSession(session: previousSession, eventType: .end)
      }
      SessionEventInstrumentation.addSession(session: transition.current, eventType: .start)
      NotificationCenter.default.post(name: SessionEventNotification, object: transition.current)
    }
    
    SessionStore.scheduleSave(session: session!)
    return session!
  }

  /// Gets the current session without extending its expireTime time
  /// - Returns: The current session if one exists, nil otherwise
  public func peekSession() -> Session? {
    return lock.withLock { session }
  }

  /// Creates a new session with a unique identifier (called within lock)
  private func startSession() -> SessionTransition {
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

    return SessionTransition(current: session!, previous: previousSession)
  }

  /// Extends the current session expiry time (called within lock)
  private func refreshSession() {
    session = Session(
      id: session!.id,
      expireTime: Date(timeIntervalSinceNow: Double(configuration.sessionTimeout)),
      previousId: session!.previousId,
      startTime: session!.startTime,
      sessionTimeout: configuration.sessionTimeout
    )
  }

  /// Restores a previously saved session from UserDefaults
  private func restoreSessionFromDisk() {
    let loadedSession = SessionStore.load()
    lock.withLock {
      session = loadedSession
    }
  }
}
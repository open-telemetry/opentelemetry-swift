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
    let (currentSession,
         previousSession,
         sessionDidExpire) = lock.withLock {
      if let session,
         !session.isExpired() {
        // extend session
        let extendedSession = locked_refreshSession(session: session)
        self.session = extendedSession
        return (extendedSession, nil as Session?, false)
      } else {
        // start new session
        let prev = session
        let nextSession = locked_startSession()
        self.session = nextSession
        return (nextSession, prev, true)
      }
    }

    // Call external code outside the lock only if new session was created
    if sessionDidExpire {
      if let previousSession {
        SessionEventInstrumentation.addSession(session: previousSession, eventType: .end)
      }
      SessionEventInstrumentation.addSession(session: currentSession, eventType: .start)
      NotificationCenter.default.post(name: SessionEventNotification, object: currentSession)
    }

    SessionStore.scheduleSave(session: currentSession)
    return currentSession
  }

  /// Gets the current session without extending its expireTime time
  /// - Returns: The current session if one exists, nil otherwise
  public func peekSession() -> Session? {
    return lock.withLock { session }
  }

  /// Creates a new session with a unique identifier
  /// *Warning* - this must be a pure function since it is used inside a lock
  private func locked_startSession() -> Session {
    let now = Date()

    return Session(
      id: UUID().uuidString,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: session?.id,
      startTime: now,
      sessionTimeout: configuration.sessionTimeout
    )
  }

  /// Extends the current session expiry time
  /// *Warning* - this must be a pure function since it is used inside a lock
  private func locked_refreshSession(session: Session) -> Session {
    return Session(
      id: session.id,
      expireTime: Date(timeIntervalSinceNow: Double(configuration.sessionTimeout)),
      previousId: session.previousId,
      startTime: session.startTime,
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

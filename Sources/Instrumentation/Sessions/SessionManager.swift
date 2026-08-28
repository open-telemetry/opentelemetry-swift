/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Manages OpenTelemetry sessions with automatic expiration and persistence.
/// Provides thread-safe access to session information and handles session lifecycle.
/// Sessions are extended only when meaningful activity is recorded.
public class SessionManager: @unchecked Sendable {
  private struct SessionAccess {
    let session: Session
    let previousSessionToEnd: Session?
    let startedNewSession: Bool
  }

  private var configuration: SessionConfig
  private var session: Session?
  private var persistedPreviousSession: Session?
  private let operationLock = NSRecursiveLock()
  private let lock = NSLock()

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter configuration: Session configuration settings
  public init(configuration: SessionConfig = .default) {
    self.configuration = configuration
    loadPersistedSessionFromDisk()
  }

  /// Gets the current session, creating a linked replacement if it has expired.
  ///
  /// Access is passive and does not extend the inactivity deadline. Call
  /// ``recordActivity()`` when a user interaction or lifecycle transition should
  /// keep the current session active.
  /// - Returns: The current active session
  @discardableResult
  public func getSession() -> Session {
    return operationLock.withLock {
      let access = lock.withLock { locked_accessSession() }
      completeAccess(access)
      return access.session
    }
  }

  /// Records meaningful user activity and extends the current session's inactivity deadline.
  ///
  /// If the previous session has already expired, this creates a linked replacement before
  /// recording the activity.
  /// - Returns: The active session after recording activity
  @discardableResult
  public func recordActivity() -> Session {
    return operationLock.withLock {
      let access = lock.withLock {
        let access = locked_accessSession()
        guard !access.startedNewSession else {
          return access
        }

        let refreshedSession = locked_refreshSession(session: access.session)
        session = refreshedSession
        return SessionAccess(
          session: refreshedSession,
          previousSessionToEnd: nil,
          startedNewSession: false
        )
      }

      if access.startedNewSession {
        completeAccess(access)
      } else {
        SessionStore.scheduleSave(session: access.session)
      }
      return access.session
    }
  }

  /// Ends the current session and starts a linked replacement.
  ///
  /// Use this after a sign-out, account change, or another explicit session boundary.
  /// The replacement is persisted before lifecycle events are emitted.
  /// - Returns: The newly created session
  @discardableResult
  public func resetSession() -> Session {
    return operationLock.withLock {
      let access = lock.withLock {
        let now = Date()
        let previousSession = session ?? persistedPreviousSession
        let previousSessionToEnd = previousSession.map { previous in
          previous.isExpired() ? previous : locked_endSession(previous, at: now)
        }
        let nextSession = locked_startSession(previousId: previousSession?.id, at: now)
        session = nextSession
        persistedPreviousSession = nil
        return SessionAccess(
          session: nextSession,
          previousSessionToEnd: previousSessionToEnd,
          startedNewSession: true
        )
      }

      completeAccess(access)
      return access.session
    }
  }

  /// Gets the current session without extending its expireTime time
  /// - Returns: The current session if one exists, nil otherwise
  public func peekSession() -> Session? {
    return lock.withLock { session }
  }

  /// Creates a new session with a unique identifier
  /// *Warning* - this must be a pure function since it is used inside a lock
  private func locked_startSession(previousId: String?, at now: Date = Date()) -> Session {
    return Session(
      id: UUID().uuidString,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: previousId,
      startTime: now,
      sessionTimeout: configuration.sessionTimeout,
      maxLifetime: configuration.maxLifetime
    )
  }

  /// Ends a restored historical session at its last known activity, capped at restore time
  private func endPersistedPreviousSession(_ session: Session) -> Session {
    guard !session.isExpired() else {
      return session
    }

    let now = Date()
    var inferredEndTime = session.expireTime.addingTimeInterval(-session.sessionTimeout)
    if inferredEndTime < session.startTime {
      inferredEndTime = session.startTime
    }
    if inferredEndTime > now {
      inferredEndTime = now
    }
    return Session(
      id: session.id,
      expireTime: inferredEndTime,
      previousId: session.previousId,
      startTime: session.startTime,
      // Pin `endTime` to `inferredEndTime`; `Session.endTime` subtracts `sessionTimeout`.
      sessionTimeout: 0,
      maxLifetime: nil
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
      sessionTimeout: configuration.sessionTimeout,
      maxLifetime: session.maxLifetime
    )
  }

  /// Returns the active session without changing its inactivity deadline.
  /// *Warning* - call only while holding `lock`.
  private func locked_accessSession() -> SessionAccess {
    if let session,
       !session.isExpired() {
      return SessionAccess(
        session: session,
        previousSessionToEnd: nil,
        startedNewSession: false
      )
    }

    let previousSession = session ?? persistedPreviousSession
    let nextSession = locked_startSession(previousId: previousSession?.id)
    session = nextSession
    persistedPreviousSession = nil
    return SessionAccess(
      session: nextSession,
      previousSessionToEnd: previousSession,
      startedNewSession: true
    )
  }

  /// Creates an ended snapshot whose end time is fixed to `date`.
  /// *Warning* - this must remain a pure function because it is called inside `lock`.
  private func locked_endSession(_ session: Session, at date: Date) -> Session {
    return Session(
      id: session.id,
      expireTime: date,
      previousId: session.previousId,
      startTime: session.startTime,
      sessionTimeout: 0,
      maxLifetime: nil
    )
  }

  /// Persists and publishes a newly started session without invoking external code under `lock`.
  private func completeAccess(_ access: SessionAccess) {
    guard access.startedNewSession else { return }

    SessionStore.saveImmediately(session: access.session)
    if let previousSessionToEnd = access.previousSessionToEnd {
      SessionEventInstrumentation.addSession(session: previousSessionToEnd, eventType: .end)
    }
    SessionEventInstrumentation.addSession(session: access.session, eventType: .start)
    NotificationCenter.default.post(name: SessionEventNotification, object: access.session)
  }

  /// Loads a saved session from UserDefaults according to the configured restore behavior
  private func loadPersistedSessionFromDisk() {
    let loadedSession = SessionStore.load()
    lock.withLock {
      if configuration.restorePersistedSession {
        session = loadedSession
      } else {
        persistedPreviousSession = loadedSession.map { endPersistedPreviousSession($0) }
      }
    }
  }
}

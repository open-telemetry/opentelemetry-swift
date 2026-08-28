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
  private let sessionStore: SessionStore
  private let operationLock = NSRecursiveLock()
  private let lock = NSLock()

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter configuration: Session configuration settings
  public init(configuration: SessionConfig = .default) {
    self.configuration = configuration
    sessionStore = SessionStore.shared
    loadPersistedSessionFromDisk()
  }

  /// Initializes a session manager with an injected persistence backend.
  /// - Parameters:
  ///   - configuration: Session configuration settings
  ///   - persistence: Backend that stores the complete versioned session record
  ///   - persistenceAccess: Whether one writer or shared writers own the record
  /// - Throws: ``SessionPersistenceConfigurationError/concurrentWritersUnsupported`` when
  ///   shared access is requested. Cross-process session transitions are not yet supported.
  public init(configuration: SessionConfig = .default,
              persistence: any SessionPersistence,
              persistenceAccess: SessionPersistenceAccess = .exclusive) throws {
    if case .shared = persistenceAccess {
      throw SessionPersistenceConfigurationError.concurrentWritersUnsupported
    }
    self.configuration = configuration
    sessionStore = SessionStore(persistence: persistence)
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
      let access = accessSession()
      completeAccess(access)
      return access.session
    }
  }

  /// Returns the persisted sampling decision for the active session.
  ///
  /// Trace, log, and metric integrations can call this method to apply the same decision.
  /// Access may create a linked replacement if the previous session has expired, but it does
  /// not extend the inactivity deadline.
  public func samplingDecision() -> SessionSamplingDecision {
    return getSession().samplingDecision
  }

  /// Records meaningful user activity and extends the current session's inactivity deadline.
  ///
  /// If the previous session has already expired, this creates a linked replacement before
  /// recording the activity.
  /// - Returns: The active session after recording activity
  @discardableResult
  public func recordActivity() -> Session {
    return operationLock.withLock {
      let access = accessSession()
      let updatedAccess: SessionAccess = if access.startedNewSession {
        access
      } else {
        lock.withLock {
          let refreshedSession = locked_refreshSession(session: access.session)
          session = refreshedSession
          return SessionAccess(
            session: refreshedSession,
            previousSessionToEnd: nil,
            startedNewSession: false
          )
        }
      }

      if updatedAccess.startedNewSession {
        completeAccess(updatedAccess)
      } else {
        sessionStore.scheduleSave(session: updatedAccess.session)
      }
      return updatedAccess.session
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
      let now = Date()
      let previousSession = lock.withLock { session ?? persistedPreviousSession }
      let previousSessionToEnd = previousSession.map { previous in
        previous.isExpired() ? previous : endedSession(previous, at: now)
      }
      let nextSession = startSession(previousId: previousSession?.id, at: now)
      let access = lock.withLock {
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

  /// Creates a new session and makes its one sampling decision.
  /// Called under `operationLock`, but outside `lock`, because samplers are caller-provided code.
  private func startSession(previousId: String?, at now: Date = Date()) -> Session {
    let id = UUID().uuidString
    return Session(
      id: id,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: previousId,
      startTime: now,
      sessionTimeout: configuration.sessionTimeout,
      maxLifetime: configuration.maxLifetime,
      samplingDecision: configuration.sampler.samplingDecision(for: id)
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
      maxLifetime: nil,
      samplingDecision: session.samplingDecision
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
      maxLifetime: session.maxLifetime,
      samplingDecision: session.samplingDecision
    )
  }

  /// Returns the active session without changing its inactivity deadline.
  /// Called under `operationLock`; state reads and writes remain protected by `lock`.
  private func accessSession() -> SessionAccess {
    let currentSession = lock.withLock { session }
    if let currentSession,
       !currentSession.isExpired() {
      return SessionAccess(
        session: currentSession,
        previousSessionToEnd: nil,
        startedNewSession: false
      )
    }

    let previousSession = lock.withLock { session ?? persistedPreviousSession }
    let nextSession = startSession(previousId: previousSession?.id)
    lock.withLock {
      session = nextSession
      persistedPreviousSession = nil
    }
    return SessionAccess(
      session: nextSession,
      previousSessionToEnd: previousSession,
      startedNewSession: true
    )
  }

  /// Creates an ended snapshot whose end time is fixed to `date`.
  private func endedSession(_ session: Session, at date: Date) -> Session {
    return Session(
      id: session.id,
      expireTime: date,
      previousId: session.previousId,
      startTime: session.startTime,
      sessionTimeout: 0,
      maxLifetime: nil,
      samplingDecision: session.samplingDecision
    )
  }

  /// Persists and publishes a newly started session without invoking external code under `lock`.
  private func completeAccess(_ access: SessionAccess) {
    guard access.startedNewSession else { return }

    sessionStore.saveImmediately(session: access.session)
    if let previousSessionToEnd = access.previousSessionToEnd {
      SessionEventInstrumentation.addSession(session: previousSessionToEnd, eventType: .end)
    }
    SessionEventInstrumentation.addSession(session: access.session, eventType: .start)
    NotificationCenter.default.post(name: SessionEventNotification, object: access.session)
  }

  /// Loads a saved session from UserDefaults according to the configured restore behavior
  private func loadPersistedSessionFromDisk() {
    guard let loadedSession = sessionStore.load() else { return }
    let restoredSession: Session
    if loadedSession.requiresMigration {
      let decision = configuration.sampler.samplingDecision(for: loadedSession.session.id)
      restoredSession = sessionWithSamplingDecision(loadedSession.session, decision: decision)
      sessionStore.migrate(loadedSession, to: restoredSession)
    } else {
      restoredSession = loadedSession.session
    }

    lock.withLock {
      if configuration.restorePersistedSession {
        session = restoredSession
      } else {
        persistedPreviousSession = endPersistedPreviousSession(restoredSession)
      }
    }
  }

  private func sessionWithSamplingDecision(_ session: Session,
                                           decision: SessionSamplingDecision) -> Session {
    return Session(
      id: session.id,
      expireTime: session.expireTime,
      previousId: session.previousId,
      startTime: session.startTime,
      sessionTimeout: session.sessionTimeout,
      maxLifetime: session.maxLifetime,
      samplingDecision: decision
    )
  }
}

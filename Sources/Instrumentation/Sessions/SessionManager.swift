/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Manages OpenTelemetry sessions with automatic expiration and persistence.
/// Provides thread-safe access to session information and handles session lifecycle.
/// Direct access and explicit activity extend a session. Telemetry attribution is passive.
public class SessionManager: @unchecked Sendable {
  private struct SessionTransition {
    let session: Session
    let previousSessionToEnd: Session?
  }

  private struct SessionAccess {
    let session: Session
    let shouldDrainEffects: Bool
  }

  private let configuration: SessionConfig
  private var session: Session?
  private var persistedPreviousSession: Session?
  private let lock = NSLock()
  private let effectsLock = NSLock()
  private let effectDrainQueue = DispatchQueue(label: "io.opentelemetry.sessions.effects")
  private var pendingTransitions: [SessionTransition] = []
  private var isDrainingEffects = false

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter configuration: Session configuration settings
  public init(configuration: SessionConfig = .default) {
    self.configuration = configuration
    loadPersistedSessionFromDisk()
  }

  /// Gets the current session, creating or extending it as needed.
  ///
  /// This preserves the existing behavior where direct access records activity.
  /// Automatic telemetry processors use the passive attribution access path instead.
  /// - Returns: The current active session
  @discardableResult
  public func getSession() -> Session {
    return accessSession(recordActivity: true)
  }

  /// Records meaningful user activity and extends the current session's inactivity deadline.
  ///
  /// If the previous session has already expired, this creates a linked replacement before
  /// recording the activity.
  /// - Returns: The active session after recording activity
  @discardableResult
  public func recordActivity() -> Session {
    return accessSession(recordActivity: true)
  }

  /// Gets the session used to attribute telemetry without recording activity.
  ///
  /// Span, log, metric, and custom processors can use this path so passive telemetry cannot keep
  /// a session alive. It creates or rotates an expired session before returning it.
  /// - Returns: The current active session
  @discardableResult
  public func getSessionForAttribution() -> Session {
    return accessSession(recordActivity: false)
  }

  /// Ends the current session and starts a linked replacement.
  ///
  /// Use this after a sign-out, account change, or another explicit session boundary.
  /// The replacement is persisted before lifecycle events are emitted.
  /// - Returns: The newly created session
  @discardableResult
  public func resetSession() -> Session {
    let access: SessionAccess = lock.withLock {
      let now = Date()
      let previousSession = session ?? persistedPreviousSession
      let previousSessionToEnd = previousSession.map { previous in
        previous.isExpired() ? previous : locked_endSession(previous, at: now)
      }
      let nextSession = locked_startSession(previousId: previousSession?.id, at: now)
      session = nextSession
      persistedPreviousSession = nil
      SessionStore.saveImmediately(session: nextSession)
      let shouldDrainEffects = enqueueTransition(SessionTransition(
        session: nextSession,
        previousSessionToEnd: previousSessionToEnd
      ))
      return SessionAccess(session: nextSession, shouldDrainEffects: shouldDrainEffects)
    }

    if access.shouldDrainEffects {
      drainClaimedTransition()
    }
    return access.session
  }

  /// Gets the current session without extending its inactivity deadline
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
  private func locked_refreshSession(session: Session, at now: Date) -> Session {
    return Session(
      id: session.id,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: session.previousId,
      startTime: session.startTime,
      sessionTimeout: configuration.sessionTimeout,
      maxLifetime: session.maxLifetime
    )
  }

  /// Returns the active session without changing its inactivity deadline.
  /// *Warning* - call only while holding `lock`.
  private func locked_accessSession(recordActivity: Bool, at now: Date) -> SessionAccess {
    if let session,
       !session.isExpired() {
      guard recordActivity else {
        return SessionAccess(session: session, shouldDrainEffects: false)
      }

      let refreshedSession = locked_refreshSession(session: session, at: now)
      self.session = refreshedSession
      SessionStore.scheduleSave(session: refreshedSession)
      return SessionAccess(session: refreshedSession, shouldDrainEffects: false)
    }

    let previousSession = session ?? persistedPreviousSession
    let nextSession = locked_startSession(previousId: previousSession?.id, at: now)
    session = nextSession
    persistedPreviousSession = nil
    SessionStore.saveImmediately(session: nextSession)
    let shouldDrainEffects = enqueueTransition(SessionTransition(
      session: nextSession,
      previousSessionToEnd: previousSession
    ))
    return SessionAccess(session: nextSession, shouldDrainEffects: shouldDrainEffects)
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

  /// Retrieves a session and queues any persistence or lifecycle work in state order.
  private func accessSession(recordActivity: Bool) -> Session {
    let access = lock.withLock {
      locked_accessSession(recordActivity: recordActivity, at: Date())
    }
    if access.shouldDrainEffects {
      drainClaimedTransition()
    }
    return access.session
  }

  /// Enqueues a transition and claims its drain while a state transition holds `lock`.
  /// Transition draining never acquires `lock` while holding `effectsLock`.
  private func enqueueTransition(_ transition: SessionTransition) -> Bool {
    return effectsLock.withLock {
      pendingTransitions.append(transition)
      guard !isDrainingEffects else { return false }
      isDrainingEffects = true
      return true
    }
  }

  /// Publishes the transition claimed by the caller without holding a lock around user code.
  ///
  /// Follow-on transitions queued by concurrent or reentrant callers are handed to a private
  /// serial queue so one caller cannot absorb unrelated exporter or observer work.
  private func drainClaimedTransition() {
    guard let transition = takeNextTransitionOrReleaseClaim() else { return }
    publish(transition)

    let shouldContinue = effectsLock.withLock {
      guard pendingTransitions.isEmpty else { return true }
      isDrainingEffects = false
      return false
    }
    if shouldContinue {
      effectDrainQueue.async { [self] in drainRemainingTransitions() }
    }
  }

  /// Drains transitions after caller-side work has been bounded to one transition.
  private func drainRemainingTransitions() {
    while let transition = takeNextTransitionOrReleaseClaim() {
      publish(transition)
    }
  }

  /// Returns the next transition or releases the drain claim atomically with the empty check.
  private func takeNextTransitionOrReleaseClaim() -> SessionTransition? {
    return effectsLock.withLock {
      guard !pendingTransitions.isEmpty else {
        isDrainingEffects = false
        return nil
      }
      return pendingTransitions.removeFirst()
    }
  }

  /// Publishes one already-persisted session transition.
  private func publish(_ transition: SessionTransition) {
    if let previousSessionToEnd = transition.previousSessionToEnd {
      SessionEventInstrumentation.addSession(session: previousSessionToEnd, eventType: .end)
    }
    SessionEventInstrumentation.addSession(session: transition.session, eventType: .start)
    NotificationCenter.default.post(name: SessionEventNotification, object: transition.session)
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

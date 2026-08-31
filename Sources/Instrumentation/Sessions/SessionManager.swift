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

  private enum EffectOperation {
    case save(Session)
    case transition(SessionTransition)

    var requiresSynchronousCompletion: Bool {
      switch self {
      case .save:
        return false
      case .transition:
        return true
      }
    }
  }

  private final class PendingEffect: @unchecked Sendable {
    let operation: EffectOperation
    let completion = DispatchSemaphore(value: 0)

    init(operation: EffectOperation) {
      self.operation = operation
    }
  }

  private struct SessionAccess {
    let session: Session
    let pendingEffect: PendingEffect?
  }

  private let configuration: SessionConfig
  private var session: Session?
  private var persistedPreviousSession: Session?
  private let lock = NSLock()
  private let effectsLock = NSLock()
  private var pendingEffects: [PendingEffect] = []
  private var isDrainingEffects = false
  private let effectDrainerThreadKey = "io.opentelemetry.sessions.effect-drainer.\(UUID().uuidString)"

  /// Initializes the session manager and restores any previous session from disk
  /// - Parameter configuration: Session configuration settings
  public init(configuration: SessionConfig = .default) {
    self.configuration = configuration
    loadPersistedSessionFromDisk()
  }

  /// Gets the current session, creating or extending it as needed.
  ///
  /// This preserves the existing behavior where direct access records activity.
  /// Automatic telemetry processors use a passive internal access path instead.
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
  /// Span and log processors use this path so passive telemetry cannot keep a session alive.
  /// - Returns: The current active session
  @discardableResult
  func getSessionForAttribution() -> Session {
    return accessSession(recordActivity: false)
  }

  /// Ends the current session and starts a linked replacement.
  ///
  /// Use this after a sign-out, account change, or another explicit session boundary.
  /// The replacement is persisted before lifecycle events are emitted.
  /// - Returns: The newly created session
  @discardableResult
  public func resetSession() -> Session {
    let (nextSession, pendingEffect): (Session, PendingEffect) = lock.withLock {
      let now = Date()
      let previousSession = session ?? persistedPreviousSession
      let previousSessionToEnd = previousSession.map { previous in
        previous.isExpired() ? previous : locked_endSession(previous, at: now)
      }
      let nextSession = locked_startSession(previousId: previousSession?.id, at: now)
      session = nextSession
      persistedPreviousSession = nil
      let effect = enqueueEffect(.transition(SessionTransition(
        session: nextSession,
        previousSessionToEnd: previousSessionToEnd
      )))
      return (nextSession, effect)
    }

    drainPendingEffects(through: pendingEffect)
    return nextSession
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
        return SessionAccess(session: session, pendingEffect: nil)
      }

      let refreshedSession = locked_refreshSession(session: session, at: now)
      self.session = refreshedSession
      return SessionAccess(
        session: refreshedSession,
        pendingEffect: enqueueEffect(.save(refreshedSession))
      )
    }

    let previousSession = session ?? persistedPreviousSession
    let nextSession = locked_startSession(previousId: previousSession?.id, at: now)
    session = nextSession
    persistedPreviousSession = nil
    let effect = enqueueEffect(.transition(SessionTransition(
      session: nextSession,
      previousSessionToEnd: previousSession
    )))
    return SessionAccess(
      session: nextSession,
      pendingEffect: effect
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

  /// Retrieves a session and queues any persistence or lifecycle work in state order.
  private func accessSession(recordActivity: Bool) -> Session {
    let access = lock.withLock {
      locked_accessSession(recordActivity: recordActivity, at: Date())
    }
    if let pendingEffect = access.pendingEffect {
      drainPendingEffects(through: pendingEffect)
    }
    return access.session
  }

  /// Enqueues an effect while a state transition holds `lock`.
  /// Effect draining never acquires `lock` while holding `effectsLock`.
  private func enqueueEffect(_ operation: EffectOperation) -> PendingEffect {
    let effect = PendingEffect(operation: operation)
    effectsLock.withLock { pendingEffects.append(effect) }
    return effect
  }

  /// Drains ordered persistence and lifecycle effects without holding a lock around user code.
  ///
  /// One caller claims the drain. Transition callers wait for persistence and publication, while
  /// coalesced activity saves may return once queued. If an exporter calls back on the drainer
  /// thread, the outer loop completes the nested effect after the callback returns.
  private func drainPendingEffects(through pendingEffect: PendingEffect) {
    let shouldDrain = effectsLock.withLock {
      guard !isDrainingEffects else { return false }
      isDrainingEffects = true
      return true
    }
    guard shouldDrain else {
      if pendingEffect.operation.requiresSynchronousCompletion,
         Thread.current.threadDictionary[effectDrainerThreadKey] == nil {
        pendingEffect.completion.wait()
      }
      return
    }

    Thread.current.threadDictionary[effectDrainerThreadKey] = true
    defer { Thread.current.threadDictionary.removeObject(forKey: effectDrainerThreadKey) }

    while true {
      guard let effect = effectsLock.withLock({ () -> PendingEffect? in
        guard !pendingEffects.isEmpty else {
          isDrainingEffects = false
          return nil
        }
        return pendingEffects.removeFirst()
      }) else {
        return
      }

      switch effect.operation {
      case let .save(session):
        SessionStore.scheduleSave(session: session)
      case let .transition(transition):
        publish(transition)
      }
      effect.completion.signal()
    }
  }

  /// Persists and publishes one session transition.
  private func publish(_ transition: SessionTransition) {
    SessionStore.saveImmediately(session: transition.session)
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

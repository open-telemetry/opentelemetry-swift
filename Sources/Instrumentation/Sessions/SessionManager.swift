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

  private struct SessionCandidate {
    let id: String
    let samplingDecision: SessionSamplingDecision
  }

  private let configuration: SessionConfig
  private var session: Session?
  private var persistedPreviousSession: Session?
  private let sessionStore: SessionStore
  private let sessionMutationLock = NSLock()
  private let sessionCreationCondition = NSCondition()
  private let lock = NSLock()
  private let effectsLock = NSLock()
  private let effectDrainQueue = DispatchQueue(label: "io.opentelemetry.sessions.effects")
  private var pendingTransitions: [SessionTransition] = []
  private var isDrainingEffects = false
  private var isCreatingSession = false

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

  /// Gets the current session, creating or extending it as needed.
  ///
  /// This preserves the existing behavior where direct access records activity.
  /// Automatic telemetry processors use the passive attribution access path instead.
  /// - Returns: The current active session
  @discardableResult
  public func getSession() -> Session {
    return accessSession(recordActivity: true)
  }

  /// Returns the persisted sampling decision for the active session.
  ///
  /// Trace, log, and metric integrations can call this method to apply the same decision.
  /// Access may create a linked replacement if the previous session has expired, but it does
  /// not extend the inactivity deadline.
  public func samplingDecision() -> SessionSamplingDecision {
    return getSessionForAttribution().samplingDecision
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
    let candidate = makeSessionCandidate()
    let access: SessionAccess = sessionMutationLock.withLock {
      let now = Date()
      let previousSession = lock.withLock { session ?? persistedPreviousSession }
      let previousSessionToEnd = previousSession.map { previous in
        previous.isExpired() ? previous : endedSession(previous, at: now)
      }
      let nextSession = startSession(candidate: candidate, previousId: previousSession?.id, at: now)
      sessionStore.saveImmediately(session: nextSession)
      lock.withLock {
        session = nextSession
        persistedPreviousSession = nil
      }
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

  /// Creates an identifier and sampling decision without holding a manager lock.
  private func makeSessionCandidate() -> SessionCandidate {
    let id = UUID().uuidString
    return SessionCandidate(
      id: id,
      samplingDecision: configuration.sampler.samplingDecision(for: id)
    )
  }

  /// Creates a new session from a previously sampled candidate.
  private func startSession(candidate: SessionCandidate, previousId: String?, at now: Date) -> Session {
    return Session(
      id: candidate.id,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: previousId,
      startTime: now,
      sessionTimeout: configuration.sessionTimeout,
      maxLifetime: configuration.maxLifetime,
      samplingDecision: candidate.samplingDecision
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
  private func refreshedSession(session: Session, at now: Date) -> Session {
    return Session(
      id: session.id,
      expireTime: now.addingTimeInterval(Double(configuration.sessionTimeout)),
      previousId: session.previousId,
      startTime: session.startTime,
      sessionTimeout: configuration.sessionTimeout,
      maxLifetime: session.maxLifetime,
      samplingDecision: session.samplingDecision
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

  /// Retrieves a session and queues any persistence or lifecycle work in state order.
  private func accessSession(recordActivity: Bool) -> Session {
    if !recordActivity,
       let currentSession = currentActiveSession() {
      return currentSession
    }

    if let activeAccess = sessionMutationLock.withLock({
      accessActiveSession(recordActivity: recordActivity, at: Date())
    }) {
      return activeAccess.session
    }

    while true {
      guard claimSessionCreation() else {
        if !recordActivity,
           let currentSession = currentActiveSession() {
          return currentSession
        }
        if let activeAccess = sessionMutationLock.withLock({
          accessActiveSession(recordActivity: recordActivity, at: Date())
        }) {
          return activeAccess.session
        }
        continue
      }

      let access: SessionAccess = {
        defer { releaseSessionCreation() }

        if let activeAccess = sessionMutationLock.withLock({
          accessActiveSession(recordActivity: recordActivity, at: Date())
        }) {
          return activeAccess
        }

        let candidate = makeSessionCandidate()
        return sessionMutationLock.withLock {
          let now = Date()
          if let activeAccess = accessActiveSession(recordActivity: recordActivity, at: now) {
            return activeAccess
          }

          let previousSession = lock.withLock { session ?? persistedPreviousSession }
          let nextSession = startSession(candidate: candidate, previousId: previousSession?.id, at: now)
          sessionStore.saveImmediately(session: nextSession)
          lock.withLock {
            session = nextSession
            persistedPreviousSession = nil
          }
          let shouldDrainEffects = enqueueTransition(SessionTransition(
            session: nextSession,
            previousSessionToEnd: previousSession
          ))
          return SessionAccess(session: nextSession, shouldDrainEffects: shouldDrainEffects)
        }
      }()

      if access.shouldDrainEffects {
        drainClaimedTransition()
      }
      return access.session
    }
  }

  /// Returns the active session, optionally recording activity. Call while holding
  /// `sessionMutationLock` so persistence and in-memory state remain ordered.
  private func accessActiveSession(recordActivity: Bool, at now: Date) -> SessionAccess? {
    guard let currentSession = currentActiveSession() else {
      return nil
    }

    guard recordActivity else {
      return SessionAccess(session: currentSession, shouldDrainEffects: false)
    }

    let updatedSession = refreshedSession(session: currentSession, at: now)
    sessionStore.scheduleSave(session: updatedSession)
    lock.withLock { session = updatedSession }
    return SessionAccess(session: updatedSession, shouldDrainEffects: false)
  }

  private func currentActiveSession() -> Session? {
    return lock.withLock {
      guard let session,
            !session.isExpired()
      else {
        return nil
      }
      return session
    }
  }

  /// Claims responsibility for creating a session. Waiters retry after the creator publishes it.
  private func claimSessionCreation() -> Bool {
    sessionCreationCondition.lock()
    defer { sessionCreationCondition.unlock() }

    guard !isCreatingSession else {
      repeat {
        sessionCreationCondition.wait()
      } while isCreatingSession
      return false
    }
    isCreatingSession = true
    return true
  }

  private func releaseSessionCreation() {
    sessionCreationCondition.lock()
    isCreatingSession = false
    sessionCreationCondition.broadcast()
    sessionCreationCondition.unlock()
  }

  /// Enqueues a transition and claims its drain while mutation order is serialized.
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

  /// Loads a saved session from the configured persistence backend.
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

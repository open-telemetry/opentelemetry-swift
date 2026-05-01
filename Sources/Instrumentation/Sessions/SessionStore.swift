/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Handles persistence of OpenTelemetry sessions to UserDefaults
/// Provides static methods for saving and loading session data
internal final class SessionStore {
  /// UserDefaults key for storing session ID
  static let idKey = "otel-session-id"
  /// UserDefaults key for storing previous session ID
  static let previousIdKey = "otel-session-previous-id"
  /// UserDefaults key for storing session expiry timestamp
  static let expireTimeKey = "otel-session-expire-time"
  /// UserDefaults key for storing session start time
  static let startTimeKey = "otel-session-start-time"
  /// UserDefaults key for storing session timeout
  static let sessionTimeoutKey = "otel-session-timeout"

  /// To avoid writing to disk too often, SessionStore only keeps the current session
  /// in memory and saves to disk on an interval (every 30 seconds).

  /// Guards all static mutable state below; every access goes through this lock so
  /// callers from different threads (`SessionManager.getSession()` callers, the
  /// repeating `saveTimer` callback, and test `teardown`) do not race.
  private static let lock = NSLock()
  /// The most recent session to be saved to disk
  nonisolated(unsafe) private static var pendingSession: Session?
  /// The previous session
  nonisolated(unsafe) private static var prevSession: Session?
  /// The interval period after which the current session is saved to disk
  private static let saveInterval: TimeInterval = 30 // in seconds
  /// The timer responsible for saving the current session to disk
  nonisolated(unsafe) private static var saveTimer: Timer?

  /// Schedules a session to be saved to UserDefaults on the next timer interval
  /// - Parameter session: The session to save
  static func scheduleSave(session: Session) {
    let needsTimer: Bool = lock.withLock {
      pendingSession = session
      return saveTimer == nil
    }

    if needsTimer {
      // save initial session
      saveImmediately(session: session)

      // `Timer.scheduledTimer` schedules on the current RunLoop; callers reach
      // here from arbitrary threads (incl. GCD workers with no run loop), so
      // pin the timer to RunLoop.main to guarantee it fires.
      let timer = Timer(timeInterval: saveInterval, repeats: true) { _ in
        let pendingToSave: Session? = lock.withLock {
          if let pending = pendingSession, prevSession != pending {
            return pending
          }
          return nil
        }
        if let pendingToSave {
          saveImmediately(session: pendingToSave)
        }
      }
      if Thread.isMainThread {
        RunLoop.main.add(timer, forMode: .common)
      } else {
        nonisolated(unsafe) let timerRef = timer
        DispatchQueue.main.async { RunLoop.main.add(timerRef, forMode: .common) }
      }
      lock.withLock { saveTimer = timer }
    }
  }

  /// Immediately saves a session to UserDefaults
  /// - Parameter session: The session to save
  static func saveImmediately(session: Session) {
    // Persist session. UserDefaults is thread-safe so the writes themselves
    // don't need our lock; only the in-memory bookkeeping does.
    UserDefaults.standard.set(session.id, forKey: idKey)
    UserDefaults.standard.set(session.expireTime, forKey: expireTimeKey)
    UserDefaults.standard.set(session.startTime, forKey: startTimeKey)
    UserDefaults.standard.set(session.previousId, forKey: previousIdKey)
    UserDefaults.standard.set(session.sessionTimeout, forKey: sessionTimeoutKey)

    lock.withLock {
      // update prev session
      prevSession = session
      // clear pending session, since it is now outdated
      pendingSession = nil
    }
  }

  /// Loads a previously saved session from UserDefaults
  /// - Returns: The saved session if ID, startTime, and expireTime exist. nil otherwise
  static func load() -> Session? {
    guard let startTime = UserDefaults.standard.object(forKey: startTimeKey) as? Date,
          let id = UserDefaults.standard.string(forKey: idKey),
          let expireTime = UserDefaults.standard.object(forKey: expireTimeKey) as? Date,
          let sessionTimeout = UserDefaults.standard.object(forKey: sessionTimeoutKey) as? TimeInterval
    else {
      return nil
    }

    let previousId = UserDefaults.standard.string(forKey: previousIdKey)

    let session = Session(
      id: id,
      expireTime: expireTime,
      previousId: previousId,
      startTime: startTime,
      sessionTimeout: sessionTimeout
    )
    lock.withLock {
      // reset sessions so it does not get overridden in the next scheduled save
      pendingSession = nil
      prevSession = session
    }
    return session
  }

  /// Cleans up timer and UserDefaults
  static func teardown() {
    let timer: Timer? = lock.withLock {
      let t = saveTimer
      saveTimer = nil
      pendingSession = nil
      prevSession = nil
      return t
    }
    timer?.invalidate()
    UserDefaults.standard.removeObject(forKey: idKey)
    UserDefaults.standard.removeObject(forKey: startTimeKey)
    UserDefaults.standard.removeObject(forKey: expireTimeKey)
    UserDefaults.standard.removeObject(forKey: previousIdKey)
    UserDefaults.standard.removeObject(forKey: sessionTimeoutKey)
  }
}
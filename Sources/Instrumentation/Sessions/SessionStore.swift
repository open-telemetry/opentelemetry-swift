/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Handles persistence of OpenTelemetry sessions to UserDefaults
/// Provides static methods for saving and loading session data
internal class SessionStore {
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

  /// The most recent session to be saved to disk
  private static var pendingSession: Session?
  /// The previous session
  private static var prevSession: Session?
  /// The interval period after which the current session is saved to disk
  private static let saveInterval: TimeInterval = 30 // in seconds
  /// The timer responsible for saving the current session to disk
  private static var saveTimer: Timer?

  /// Schedules a session to be saved to UserDefaults on the next timer interval
  /// - Parameter session: The session to save
  static func scheduleSave(session: Session) {
    pendingSession = session

    if saveTimer == nil {
      // save initial session
      saveImmediately(session: session)

      // save future sessions on a interval
      saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { _ in
        // only write to disk if it is a new sesssion
        if let pending = pendingSession, prevSession != pending {
          saveImmediately(session: pending)
        }
      }
    }
  }

  /// Immediately saves a session to UserDefaults
  /// - Parameter session: The session to save
  static func saveImmediately(session: Session) {
    // Persist session
    UserDefaults.standard.set(session.id, forKey: idKey)
    UserDefaults.standard.set(session.expireTime, forKey: expireTimeKey)
    UserDefaults.standard.set(session.startTime, forKey: startTimeKey)
    UserDefaults.standard.set(session.previousId, forKey: previousIdKey)
    UserDefaults.standard.set(session.sessionTimeout, forKey: sessionTimeoutKey)

    // update prev session
    prevSession = session
    // clear pending session, since it is now outdated
    pendingSession = nil
  }

  /// Loads a previously saved session from UserDefaults
  /// - Returns: The saved session if ID, startTime, and expireTime exist. nil otherwise
  static func load() -> Session? {
    guard let startTime = UserDefaults.standard.object(forKey: startTimeKey) as? Date,
          let id = UserDefaults.standard.string(forKey: idKey),
          let expireTime = UserDefaults.standard.object(forKey: expireTimeKey) as? Date,
          let sessionTimeout = UserDefaults.standard.object(forKey: sessionTimeoutKey) as? Int
    else {
      return nil
    }

    let previousId = UserDefaults.standard.string(forKey: previousIdKey)

    // reset sessions so it does not get overridden in the next scheduled save
    pendingSession = nil
    prevSession = Session(
      id: id,
      expireTime: expireTime,
      previousId: previousId,
      startTime: startTime,
      sessionTimeout: sessionTimeout
    )
    return prevSession
  }

  /// Cleans up timer and UserDefaults
  static func teardown() {
    saveTimer?.invalidate()
    saveTimer = nil
    pendingSession = nil
    prevSession = nil
    UserDefaults.standard.removeObject(forKey: idKey)
    UserDefaults.standard.removeObject(forKey: startTimeKey)
    UserDefaults.standard.removeObject(forKey: expireTimeKey)
    UserDefaults.standard.removeObject(forKey: previousIdKey)
    UserDefaults.standard.removeObject(forKey: sessionTimeoutKey)
  }
}
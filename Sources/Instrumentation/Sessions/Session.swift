/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Represents an OpenTelemetry session with lifecycle management.
///
/// A session tracks user activity with automatic expiration and renewal capabilities.
/// Sessions include unique identifiers, timestamps, and linkage to previous sessions.
///
/// Example:
/// ```swift
/// let session = Session(
///     id: UUID().uuidString,
///     expireTime: Date(timeIntervalSinceNow: 1800),
///     previousId: "previous-session-id"
/// )
///
/// if session.isExpired() {
///     print("Session ended at: \(session.endTime!)")
///     print("Duration: \(session.duration!) seconds")
/// }
/// ```
public struct Session: Equatable, Sendable {
  /// Unique identifier for the session
  public let id: String
  /// Expiration time for the session
  public let expireTime: Date
  /// Unique identifier of the user's previous session, if any
  public let previousId: String?
  /// Start time of the session
  public let startTime: Date
  /// The duration in seconds after which this session expires if inactive
  public let sessionTimeout: TimeInterval
  /// The maximum duration in seconds this session can remain active, regardless of activity
  public let maxLifetime: TimeInterval?

  /// Creates a new session
  /// - Parameters:
  ///   - id: Unique identifier for the session
  ///   - expireTime: Expiration time for the session
  ///   - previousId: Unique identifier of the user's previous session, if any
  ///   - startTime: Start time of the session, defaults to current time
  ///   - sessionTimeout: Duration in seconds after which the session expires if inactive
  ///   - maxLifetime: Maximum duration in seconds the session can remain active, regardless of activity
  public init(id: String,
              expireTime: Date,
              previousId: String? = nil,
              startTime: Date = Date(),
              sessionTimeout: TimeInterval = SessionConfig.default.sessionTimeout,
              maxLifetime: TimeInterval? = SessionConfig.default.maxLifetime) {
    self.id = id
    self.expireTime = expireTime
    self.previousId = previousId
    self.startTime = startTime
    self.sessionTimeout = sessionTimeout
    self.maxLifetime = maxLifetime
  }

  /// Two sessions are considered equal if they have the same ID, prevID, startTime, and expiry timestamp
  public static func == (lhs: Session, rhs: Session) -> Bool {
    return lhs.expireTime == rhs.expireTime &&
      lhs.id == rhs.id &&
      lhs.previousId == rhs.previousId &&
      lhs.startTime == rhs.startTime &&
      lhs.sessionTimeout == rhs.sessionTimeout &&
      lhs.maxLifetime == rhs.maxLifetime
  }

  /// Checks if the session has expired
  /// - Returns: True if the current time is past the session's inactivity expiry or maximum lifetime
  public func isExpired() -> Bool {
    return expirationTime <= Date()
  }

  /// The time when the session ended (only available for expired sessions).
  ///
  /// For expired sessions, this returns the calculated end time based on when the session
  /// was last active. For active sessions, this returns nil.
  /// - Returns: The session end time, or nil if the session is still active
  public var endTime: Date? {
    guard isExpired() else { return nil }
    if let maxLifetimeExpirationTime, maxLifetimeExpirationTime <= expireTime {
      return maxLifetimeExpirationTime
    }
    return expireTime.addingTimeInterval(-Double(sessionTimeout))
  }

  /// The total duration the session was active (only available for expired sessions).
  ///
  /// Calculates the time between session start and end. Only available for expired sessions.
  /// - Returns: The session duration in seconds, or nil if the session is still active
  public var duration: TimeInterval? {
    guard let endTime else { return nil }
    return endTime.timeIntervalSince(startTime)
  }

  private var expirationTime: Date {
    guard let maxLifetimeExpirationTime else {
      return expireTime
    }
    return min(expireTime, maxLifetimeExpirationTime)
  }

  private var maxLifetimeExpirationTime: Date? {
    guard let maxLifetime else {
      return nil
    }
    return startTime.addingTimeInterval(maxLifetime)
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Protocol defining the contract for Faro session management
protocol FaroSessionManaging {
  /// Callback that will be called when the session ID changes
  /// - Parameters:
  ///   - previousId: The previous session ID
  ///   - newId: The new session ID
  var onSessionIdChanged: ((String, String) -> Void)? { get set }

  /// Returns the full session object
  /// - Returns: The FaroSession object
  func getSession() -> FaroSession

  /// Updates the last activity date for the session
  /// - Parameter date: The new last activity date
  func updateLastActivity(date: Date)
}

/// Factory for creating and managing the singleton instance of FaroSessionManager
final class FaroSessionManagerFactory {
  private static var shared: FaroSessionManager?

  private init() {}

  /// Creates or returns the shared instance of FaroSessionManager
  /// - Parameter dateProvider: Provider for current date, defaults to DateProvider
  /// - Returns: The shared FaroSessionManager instance
  static func getInstance(dateProvider: DateProviding = DateProvider(), deviceAttributesProvider: FaroDeviceAttributesProviding = FaroDeviceAttributesProviderFactory.createProvider()) -> FaroSessionManager {
    if let existingManager = shared {
      return existingManager
    }
    let manager = FaroSessionManager(dateProvider: dateProvider, deviceAttributesProvider: deviceAttributesProvider)
    shared = manager
    return manager
  }
}

/// Default implementation of the FaroSessionManaging protocol
class FaroSessionManager: FaroSessionManaging {
  private static let sessionExpirationInterval: TimeInterval = 4 * 60 * 60 // 4 hours in seconds
  private static let sessionInactivityExpirationInterval: TimeInterval = 15 * 60 // 15 minutes in seconds

  private var sessionId: String
  private var sessionStartDate: Date
  private var lastActivityDate: Date
  private let dateProvider: DateProviding
  private let deviceAttributes: [String: String]

  /// Callback that will be called when the session ID changes
  var onSessionIdChanged: ((String, String) -> Void)?

  init(dateProvider: DateProviding,
       deviceAttributesProvider: FaroDeviceAttributesProviding) {
    self.dateProvider = dateProvider
    let now = dateProvider.currentDate()
    sessionStartDate = now
    lastActivityDate = now

    sessionId = UUID().uuidString
    deviceAttributes = deviceAttributesProvider.getDeviceAttributes()
  }

  func getSession() -> FaroSession {
    if !isSessionValid() {
      refreshSession()
    }
    return FaroSession(id: sessionId, attributes: deviceAttributes)
  }

  private func isSessionValid() -> Bool {
    let currentDate = dateProvider.currentDate()
    return isSessionWithinMaxLifetime(currentDate: currentDate) && isSessionWithinInactivityLimit(currentDate: currentDate)
  }

  private func isSessionWithinMaxLifetime(currentDate: Date) -> Bool {
    return currentDate.timeIntervalSince(sessionStartDate) < Self.sessionExpirationInterval
  }

  private func isSessionWithinInactivityLimit(currentDate: Date) -> Bool {
    return currentDate.timeIntervalSince(lastActivityDate) < Self.sessionInactivityExpirationInterval
  }

  private func refreshSession() {
    let previousId = sessionId
    sessionStartDate = dateProvider.currentDate()
    lastActivityDate = sessionStartDate
    sessionId = UUID().uuidString
    onSessionIdChanged?(previousId, sessionId)
  }

  func updateLastActivity(date: Date) {
    if date > lastActivityDate {
      lastActivityDate = date
    }
  }
}

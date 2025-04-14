/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import Foundation

/// Protocol defining the contract for Faro session management
protocol FaroSessionManaging {
    /// Returns the current session identifier
    /// - Returns: A string representing the current session ID
    func getSessionId() -> String
    
    /// Callback that will be called when the session ID changes
    /// - Parameters:
    ///   - previousId: The previous session ID
    ///   - newId: The new session ID
    var onSessionIdChanged: ((String, String) -> Void)? { get set }
}

/// Factory for creating and managing the singleton instance of FaroSessionManager
final class FaroSessionManagerFactory {
    private static var shared: FaroSessionManager?
    
    private init() {}
    
    /// Creates or returns the shared instance of FaroSessionManager
    /// - Parameter dateProvider: Provider for current date, defaults to DateProvider
    /// - Returns: The shared FaroSessionManager instance
    static func shared(dateProvider: DateProviding = DateProvider()) -> FaroSessionManager {
        if let existingManager = shared {
            return existingManager
        }
        let manager = FaroSessionManager(dateProvider: dateProvider)
        shared = manager
        return manager
    }
}

/// Default implementation of the FaroSessionManaging protocol
class FaroSessionManager: FaroSessionManaging {
    private static let sessionExpirationInterval: TimeInterval = 4 * 60 * 60  // 4 hours in seconds
    
    private var sessionId: String
    private var sessionStartDate: Date
    private let dateProvider: DateProviding
    
    /// Callback that will be called when the session ID changes
    var onSessionIdChanged: ((String, String) -> Void)?
    
    init(dateProvider: DateProviding) {
        self.dateProvider = dateProvider
        self.sessionStartDate = dateProvider.currentDate()
        self.sessionId = UUID().uuidString
    }
    
    func getSessionId() -> String {
        if !isSessionValid() {
            refreshSession()
        }
        return sessionId
    }

    private func isSessionValid() -> Bool {
        let currentDate = dateProvider.currentDate()
        return currentDate.timeIntervalSince(sessionStartDate) < Self.sessionExpirationInterval
    }

    private func refreshSession() {
        let previousId = sessionId
        sessionStartDate = dateProvider.currentDate()
        sessionId = UUID().uuidString
        onSessionIdChanged?(previousId, sessionId)
    }
} 
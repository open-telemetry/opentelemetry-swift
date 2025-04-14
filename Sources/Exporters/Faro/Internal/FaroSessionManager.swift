/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import Foundation

/// Protocol defining the contract for Faro session management
public protocol FaroSessionManaging {
    /// Returns the current session identifier
    /// - Returns: A string representing the current session ID
    func getSessionId() -> String
}

/// Factory for creating and managing the singleton instance of FaroSessionManager
public final class FaroSessionManagerFactory {
    private static var shared: FaroSessionManager?
    
    private init() {}
    
    /// Creates or returns the shared instance of FaroSessionManager
    /// - Parameter dateProvider: Provider for current date, defaults to DateProvider
    /// - Returns: The shared FaroSessionManager instance
    public static func shared(dateProvider: DateProviding = DateProvider()) -> FaroSessionManager {
        if let existingManager = shared {
            return existingManager
        }
        let manager = FaroSessionManager(dateProvider: dateProvider)
        shared = manager
        return manager
    }
}

/// Default implementation of the FaroSessionManaging protocol
public class FaroSessionManager: FaroSessionManaging {
    private static let sessionExpirationInterval: TimeInterval = 4 * 60 * 60  // 4 hours in seconds
    
    private var sessionId: String
    private var sessionStartDate: Date
    private let dateProvider: DateProviding
    
    init(dateProvider: DateProviding) {
        self.dateProvider = dateProvider
        self.sessionStartDate = dateProvider.currentDate()
        self.sessionId = UUID().uuidString
    }
    
    public func getSessionId() -> String {
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
        sessionStartDate = dateProvider.currentDate()
        sessionId = UUID().uuidString
    }
} 
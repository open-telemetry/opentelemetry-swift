/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Provides thread-safe singleton access to SessionManager.
///
/// Use this provider to ensure consistent session management across your application.
/// Register a configured SessionManager instance or let it create a default one.
///
/// Example:
/// ```swift
/// // Register a custom session manager
/// let customManager = SessionManager(configuration: SessionConfig(sessionTimeout: 3600))
/// SessionManagerProvider.register(sessionManager: customManager)
///
/// // Access from anywhere in your app
/// let session = SessionManagerProvider.getInstance().getSession()
/// ```
public class SessionManagerProvider {
  private static var _instance: SessionManager?
  private static let lock = NSLock()
  
  /// Registers a SessionManager instance as the singleton.
  ///
  /// Call this early in your app lifecycle to ensure consistent session management.
  /// - Parameter sessionManager: The SessionManager instance to register
  public static func register(sessionManager: SessionManager) {
    lock.withLock {
      _instance = sessionManager
    }
  }
  
  /// Returns the registered SessionManager instance or creates a default one.
  ///
  /// Thread-safe method that returns the singleton SessionManager instance.
  /// If no instance has been registered, creates one with default configuration.
  /// - Returns: The singleton SessionManager instance
  public static func getInstance() -> SessionManager {
    return lock.withLock {
      if _instance == nil {
        _instance = SessionManager()
      }
      return _instance!
    }
  }
}
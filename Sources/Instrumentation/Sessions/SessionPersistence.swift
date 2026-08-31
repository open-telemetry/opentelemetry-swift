/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Stores the encoded session record used by ``SessionManager``.
///
/// Implementations must serialize access to each logical record within their supported
/// ownership model. Calls run without the ``SessionManager`` state lock held, so a backend may
/// inspect the current session with ``SessionManager/peekSession()``. A backend must not call
/// session APIs that can write persistence from inside these methods.
public protocol SessionPersistence: Sendable {
  /// Reads the complete encoded record, or `nil` when no record exists.
  func read() -> Data?

  /// Replaces the complete encoded record.
  func write(_ data: Data)

  /// Removes the encoded record.
  func clear()
}

/// Declares how a ``SessionManager`` will own an injected persistence record.
public enum SessionPersistenceAccess: Sendable {
  /// The caller guarantees that one manager in one process writes this record at a time.
  case exclusive
  /// Multiple managers or processes may write this record concurrently.
  case shared
}

/// Errors raised when persistence ownership does not match the backend's guarantees.
public enum SessionPersistenceConfigurationError: Error, Equatable {
  /// Shared access was requested from a backend that does not coordinate concurrent writers.
  case concurrentWritersUnsupported
}

/// A namespaced session record stored in `UserDefaults`.
///
/// This backend serializes calls made through one instance, but `UserDefaults` does not
/// provide a cross-process transaction. Use `.exclusive` access and one writer for a given
/// suite and namespace.
public final class UserDefaultsSessionPersistence: SessionPersistence, @unchecked Sendable {
  /// The namespace used by the default session persistence.
  public static let defaultNamespace = "otel-session"

  private let userDefaults: UserDefaults
  private let namespace: String
  private let lock = NSLock()

  var recordKey: String {
    "\(namespace)-record"
  }

  var idKey: String {
    "\(namespace)-id"
  }

  var previousIdKey: String {
    "\(namespace)-previous-id"
  }

  var expireTimeKey: String {
    "\(namespace)-expire-time"
  }

  var startTimeKey: String {
    "\(namespace)-start-time"
  }

  var sessionTimeoutKey: String {
    "\(namespace)-timeout"
  }

  var maxLifetimeKey: String {
    "\(namespace)-max-lifetime"
  }

  /// Creates persistence backed by a `UserDefaults` instance and namespace.
  /// - Parameters:
  ///   - userDefaults: Defaults storage. Pass an App Group suite to place the record there.
  ///   - namespace: Key namespace used to isolate this session record.
  public init(userDefaults: UserDefaults = .standard,
              namespace: String = UserDefaultsSessionPersistence.defaultNamespace) {
    self.userDefaults = userDefaults
    self.namespace = namespace
  }

  /// Creates persistence backed by a named `UserDefaults` suite.
  /// - Parameters:
  ///   - suiteName: Suite name, including an App Group suite identifier when applicable.
  ///   - namespace: Key namespace used to isolate this session record.
  public convenience init?(suiteName: String,
                           namespace: String = UserDefaultsSessionPersistence.defaultNamespace) {
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
      return nil
    }
    self.init(userDefaults: userDefaults, namespace: namespace)
  }

  public func read() -> Data? {
    return lock.withLock { userDefaults.data(forKey: recordKey) }
  }

  public func write(_ data: Data) {
    lock.withLock { userDefaults.set(data, forKey: recordKey) }
  }

  public func clear() {
    lock.withLock { userDefaults.removeObject(forKey: recordKey) }
  }

  func loadLegacySession() -> Session? {
    return lock.withLock {
      guard let startTime = userDefaults.object(forKey: startTimeKey) as? Date,
            let id = userDefaults.string(forKey: idKey),
            let expireTime = userDefaults.object(forKey: expireTimeKey) as? Date,
            let sessionTimeout = userDefaults.object(forKey: sessionTimeoutKey) as? TimeInterval
      else {
        return nil
      }

      return Session(
        id: id,
        expireTime: expireTime,
        previousId: userDefaults.string(forKey: previousIdKey),
        startTime: startTime,
        sessionTimeout: sessionTimeout,
        maxLifetime: userDefaults.object(forKey: maxLifetimeKey) as? TimeInterval
      )
    }
  }

  func clearLegacySession() {
    lock.withLock {
      userDefaults.removeObject(forKey: idKey)
      userDefaults.removeObject(forKey: previousIdKey)
      userDefaults.removeObject(forKey: expireTimeKey)
      userDefaults.removeObject(forKey: startTimeKey)
      userDefaults.removeObject(forKey: sessionTimeoutKey)
      userDefaults.removeObject(forKey: maxLifetimeKey)
    }
  }
}

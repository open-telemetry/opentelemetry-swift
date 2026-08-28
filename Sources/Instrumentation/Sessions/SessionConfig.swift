/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Configuration object for session management settings.
///
/// Controls session behavior including timeout duration, maximum lifetime, and persistence.
/// Sessions automatically expire after the specified timeout period of inactivity and can
/// optionally expire after a maximum lifetime.
///
/// Example:
/// ```swift
/// // Direct initialization
/// let config = SessionConfig(sessionTimeout: 45 * 60) // 45 minutes
///
/// // Using builder pattern
/// let config = SessionConfig.builder()
///   .with(sessionTimeout: 45 * 60)
///   .with(maxLifetime: 4 * 60 * 60)
///   .build()
///
/// let manager = SessionManager(configuration: config)
/// ```
public struct SessionConfig: Sendable {
  /// Duration in seconds after which a session expires if left inactive
  public let sessionTimeout: TimeInterval

  /// Maximum duration in seconds a session can remain active, regardless of activity
  public let maxLifetime: TimeInterval?

  /// Whether a previously saved session should be resumed as the current session
  public let restorePersistedSession: Bool

  /// Sampler used once whenever a new session identifier is created
  public let sampler: any SessionSampler

  /// Creates a new session configuration
  /// - Parameters:
  ///   - sessionTimeout: Duration in seconds after which a session expires if left inactive (default 30 minutes)
  ///   - maxLifetime: Maximum duration in seconds a session can remain active, regardless of activity (default disabled)
  ///   - restorePersistedSession: Whether a previously saved session should be resumed as current (default true).
  ///     When false, a new session starts and the saved session is linked as previous.
  ///   - sampler: Sampler used once for each newly created session
  public init(sessionTimeout: TimeInterval = 30 * 60,
              maxLifetime: TimeInterval? = nil,
              restorePersistedSession: Bool = true,
              sampler: any SessionSampler = AlwaysOnSessionSampler()) {
    self.sessionTimeout = sessionTimeout
    self.maxLifetime = maxLifetime
    self.restorePersistedSession = restorePersistedSession
    self.sampler = sampler
  }

  /// Default configuration with 30-minute session timeout
  public static let `default` = SessionConfig()
}

/// Builder for creating SessionConfig instances with a fluent API.
///
/// Provides a convenient way to configure session settings using method chaining.
///
/// Example:
/// ```swift
/// let config = SessionConfig.builder()
///   .with(sessionTimeout: 45 * 60)
///   .build()
/// ```
public class SessionConfigBuilder {
  public private(set) var sessionTimeout: TimeInterval = 30 * 60
  public private(set) var maxLifetime: TimeInterval?
  public private(set) var restorePersistedSession = true
  public private(set) var sampler: any SessionSampler = AlwaysOnSessionSampler()

  /// Sets the session timeout duration
  /// - Parameter sessionTimeout: Duration in seconds after which a session expires if left inactive
  /// - Returns: The builder instance for method chaining
  public func with(sessionTimeout: TimeInterval) -> Self {
    self.sessionTimeout = sessionTimeout
    return self
  }

  /// Sets the maximum duration a session can remain active
  /// - Parameter maxLifetime: Maximum duration in seconds a session can remain active, regardless of activity
  /// - Returns: The builder instance for method chaining
  public func with(maxLifetime: TimeInterval?) -> Self {
    self.maxLifetime = maxLifetime
    return self
  }

  /// Sets whether a previously saved session should be resumed as the current session
  /// - Parameter restorePersistedSession: Whether persisted sessions should be resumed as current.
  ///   When false, a new session starts and the saved session is linked as previous.
  /// - Returns: The builder instance for method chaining
  public func with(restorePersistedSession: Bool) -> Self {
    self.restorePersistedSession = restorePersistedSession
    return self
  }

  /// Sets the sampler used once for each new session
  /// - Parameter sampler: Session sampler to use
  /// - Returns: The builder instance for method chaining
  public func with(sampler: any SessionSampler) -> Self {
    self.sampler = sampler
    return self
  }

  /// Builds the SessionConfig with the configured settings
  /// - Returns: A new SessionConfig instance
  public func build() -> SessionConfig {
    return SessionConfig(
      sessionTimeout: sessionTimeout,
      maxLifetime: maxLifetime,
      restorePersistedSession: restorePersistedSession,
      sampler: sampler
    )
  }
}

/// Extension to SessionConfig for builder pattern support
public extension SessionConfig {
  /// Creates a new SessionConfigBuilder instance
  /// - Returns: A new builder for creating SessionConfig
  static func builder() -> SessionConfigBuilder {
    return SessionConfigBuilder()
  }
}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Configuration object for session management settings.
///
/// Controls session behavior including timeout duration and expiration handling.
/// Sessions automatically expire after the specified timeout period of inactivity.
///
/// Example:
/// ```swift
/// // Direct initialization
/// let config = SessionConfig(sessionTimeout: 45 * 60) // 45 minutes
/// 
/// // Using builder pattern
/// let config = SessionConfig.builder()
///   .with(sessionTimeout: 45 * 60)
///   .build()
/// 
/// let manager = SessionManager(configuration: config)
/// ```
public struct SessionConfig {
  /// Duration in seconds after which a session expires if left inactive
  public let sessionTimeout: Int
  
  /// Creates a new session configuration
  /// - Parameter sessionTimeout: Duration in seconds after which a session expires if left inactive (default 30 minutes)
  public init(sessionTimeout: Int = 30 * 60) {
    self.sessionTimeout = sessionTimeout
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
  public private(set) var sessionTimeout: Int = 30 * 60
  
  public init() {}
  
  /// Sets the session timeout duration
  /// - Parameter sessionTimeout: Duration in seconds after which a session expires if left inactive
  /// - Returns: The builder instance for method chaining
  public func with(sessionTimeout: Int) -> Self {
    self.sessionTimeout = sessionTimeout
    return self
  }
  
  /// Builds the SessionConfig with the configured settings
  /// - Returns: A new SessionConfig instance
  public func build() -> SessionConfig {
    return SessionConfig(sessionTimeout: sessionTimeout)
  }
}

/// Extension to SessionConfig for builder pattern support
extension SessionConfig {
  /// Creates a new SessionConfigBuilder instance
  /// - Returns: A new builder for creating SessionConfig
  public static func builder() -> SessionConfigBuilder {
    return SessionConfigBuilder()
  }
}
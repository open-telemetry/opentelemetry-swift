/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// - Note: Requires `Sendable`: a context manager is registered globally and invoked
///   from every thread that starts or ends spans, so any correct implementation must
///   already be thread-safe.
public protocol ContextManager: AnyObject, Sendable {
  func getCurrentContextValue(forKey: OpenTelemetryContextKeys) -> AnyObject?
  func setCurrentContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject)
  func removeContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject)

  /// Updates the current context value with the given key for the duration of the passed closure.
  /// If `value` is non-`nil` the key is set to that value.
  /// If `value` is `nil` the key is removed from the current context for the duration of the closure.
  func withCurrentContextValue<T>(forKey: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () throws -> T) rethrows -> T
  #if canImport(_Concurrency)
    /// Updates the current context value with the given key for the duration of the passed closure.
    /// If `value` is non-`nil` the key is set to that value.
    /// If `value` is `nil` the key is removed from the current context for the duration of the closure.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func withCurrentContextValue<T>(forKey: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () async throws -> T) async rethrows -> T
  #endif
}

/// A context manager which always supports the get, set, and remove operations.
/// These context managers can implement `withCurrentContextValue` in terms of these operations instead of requiring a custom implementation.
public protocol ImperativeContextManager: ContextManager {}

public extension ContextManager where Self: ImperativeContextManager {
  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func withCurrentContextValue<T>(forKey key: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () async throws -> T) async rethrows -> T {
    var oldValue: AnyObject?
    let previousValue = getCurrentContextValue(forKey: key)

    if let value {
      setCurrentContextValue(forKey: key, value: value)
    } else if let previousValue {
      removeContextValue(forKey: key, value: previousValue)
    }

    defer {
      if let previousValue {
        setCurrentContextValue(forKey: key, value: previousValue)
      } else if let value {
        removeContextValue(forKey: key, value: value)
      }
    }

    return try await operation()
  }

  func withCurrentContextValue<T>(forKey key: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () throws -> T) rethrows -> T {
    var oldValue: AnyObject?
    let previousValue = getCurrentContextValue(forKey: key)

    if let value {
      setCurrentContextValue(forKey: key, value: value)
    } else if let previousValue {
      removeContextValue(forKey: key, value: previousValue)
    }

    defer {
      if let previousValue {
        setCurrentContextValue(forKey: key, value: previousValue)
      } else if let value {
        removeContextValue(forKey: key, value: value)
      }
    }

    return try operation()
  }
}

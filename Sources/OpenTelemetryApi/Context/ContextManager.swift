/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ContextManager: AnyObject {
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
    if let value {
      setCurrentContextValue(forKey: key, value: value)
    } else {
      // Remove the current value for the key for the duration of the closure
      oldValue = getCurrentContextValue(forKey: key)
      if let oldValue {
        removeContextValue(forKey: key, value: oldValue)
      }
    }

    defer {
      if let value {
        // Remove the given value from the context after the closure finishes
        self.removeContextValue(forKey: key, value: value)
      } else {
        // Restore the previous value for the key after the closure exits
        if let oldValue {
          self.setCurrentContextValue(forKey: key, value: oldValue)
        }
      }
    }

    return try await operation()
  }

  func withCurrentContextValue<T>(forKey key: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () throws -> T) rethrows -> T {
    var oldValue: AnyObject?
    if let value {
      setCurrentContextValue(forKey: key, value: value)
    } else {
      // Remove the current value for the key for the duration of the closure
      oldValue = getCurrentContextValue(forKey: key)
      if let oldValue {
        removeContextValue(forKey: key, value: oldValue)
      }
    }

    defer {
      if let value {
        // Remove the given value from the context after the closure finishes
        self.removeContextValue(forKey: key, value: value)
      } else {
        // Restore the previous value for the key after the closure exits
        if let oldValue {
          self.setCurrentContextValue(forKey: key, value: oldValue)
        }
      }
    }

    return try operation()
  }
}

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

/// A `ContextManager` that keeps the active span and baggage in
/// `Thread.current.threadDictionary`.
///
/// The SDK's default managers are built around `os_activity` or task-locals,
/// which is the right behaviour in production but makes stress tests that
/// install per-thread context from plain `Thread`s nondeterministic. Swap
/// this in with `OpenTelemetry.withContextManager(_:_:)` for tests that only
/// need "each worker thread sees its own context".
public final class ThreadLocalContextManager: ImperativeContextManager, @unchecked Sendable {
  private static let prefix = "io.opentelemetry.ThreadLocalContextManager."

  public init() {}

  private func storageKey(_ key: OpenTelemetryContextKeys) -> String {
    Self.prefix + key.rawValue
  }

  public func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
    Thread.current.threadDictionary[storageKey(key)] as AnyObject?
  }

  public func setCurrentContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
    Thread.current.threadDictionary[storageKey(key)] = value
  }

  public func removeContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
    let dictionary = Thread.current.threadDictionary
    if let current = dictionary[storageKey(key)] as AnyObject?, current === value {
      dictionary.removeObject(forKey: storageKey(key))
    }
  }
}

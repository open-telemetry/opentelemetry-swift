/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Numbers navigations within a session, and keeps the count across restarts that resume it.
///
/// One `UserDefaults` key holds the session's identifier and its last number. A new session
/// overwrites that one entry, so no key outlives the session it counts.
final class NavigationSequence: @unchecked Sendable {
  static let defaultsKey = "io.opentelemetry.screen.navigation_sequence"
  private static let sessionIdField = "session_id"
  private static let sequenceField = "sequence"

  private let lock = NSLock()
  private let defaults: UserDefaults

  init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  /// Returns the next number for `sessionId`: one more than the last, or 1 for a new session.
  func next(sessionId: String) -> Int {
    lock.withLock {
      let stored = defaults.dictionary(forKey: Self.defaultsKey)
      let last = stored?[Self.sessionIdField] as? String == sessionId
        ? stored?[Self.sequenceField] as? Int ?? 0
        : 0
      let sequence = last + 1
      defaults.set([Self.sessionIdField: sessionId, Self.sequenceField: sequence],
                   forKey: Self.defaultsKey)
      return sequence
    }
  }
}

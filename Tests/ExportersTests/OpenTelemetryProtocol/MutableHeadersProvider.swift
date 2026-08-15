/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

final class MutableHeadersProvider: @unchecked Sendable {
  private let lock = NSLock()
  private var headers: [(String, String)]?
  private var calls = 0

  init(_ headers: [(String, String)]?) {
    self.headers = headers
  }

  func currentHeaders() -> [(String, String)]? {
    lock.lock()
    defer { lock.unlock() }
    calls += 1
    return headers
  }

  func update(_ headers: [(String, String)]?) {
    lock.lock()
    defer { lock.unlock() }
    self.headers = headers
  }

  var callCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return calls
  }
}

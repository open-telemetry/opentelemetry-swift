/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Bounds the entries a propagator accepts from a carrier or writes to one. The limits are the
/// W3C Baggage ones, used for formats that define none of their own. https://www.w3.org/TR/baggage/#limits
struct BaggagePropagationLimits {
  /// The maximum number of entries. The value is 64.
  static let maxEntries = 64
  /// The maximum number of bytes of keys and values together. The value is 8192.
  static let maxBytes = 8192

  private(set) var entries = 0
  private(set) var bytes = 0

  /// Returns whether the entry fits the remaining budget, and counts it if it does.
  mutating func accept(key: EntryKey, value: EntryValue) -> Bool {
    let size = key.name.utf8.count + value.string.utf8.count
    guard entries < BaggagePropagationLimits.maxEntries, bytes + size <= BaggagePropagationLimits.maxBytes else {
      return false
    }

    entries += 1
    bytes += size
    return true
  }
}

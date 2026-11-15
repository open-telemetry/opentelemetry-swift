/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An immutable implementation of the Baggage that does not contain any entries.
final class EmptyBaggage: Baggage, Sendable {
  private init() {}

  /// Returns the single instance of the EmptyBaggage class.
  static let instance = EmptyBaggage()

  static func baggageBuilder() -> BaggageBuilder {
    return EmptyBaggageBuilder()
  }

  func getEntries() -> [Entry] {
    return [Entry]()
  }

  func getEntryValue(key: EntryKey) -> EntryValue? {
    return nil
  }
}

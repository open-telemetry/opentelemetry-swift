/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An immutable implementation of the Baggage that does not contain any entries.
class EmptyBaggage: Baggage {
  private init() {}

  /// Returns the single instance of the EmptyBaggage class.
  static var instance = EmptyBaggage()

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

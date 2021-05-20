/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public final class DefaultBaggage: Baggage, Equatable {
    // The types of the EntryKey and Entry must match for each entry.
    var entries: [EntryKey: Entry?]

    /// Creates a new DefaultBaggage with the given entries.
    /// - Parameters:
    ///   - entries: the initial entries for this BaggageSdk
    ///   - parent: parent providing a default set of entries
    public init(entries: [EntryKey: Entry?]) {
        self.entries = entries
    }

    public static func baggageBuilder() -> BaggageBuilder {
        return DefaultBaggageBuilder()
    }

    public func getEntries() -> [Entry] {
        return Array(entries.values).compactMap { $0 }
    }

    public func getEntryValue(key: EntryKey) -> EntryValue? {
        return entries[key]??.value
    }

    static public func == (lhs: DefaultBaggage, rhs: DefaultBaggage) -> Bool {
        return lhs.getEntries().sorted() == rhs.getEntries().sorted()
    }
}


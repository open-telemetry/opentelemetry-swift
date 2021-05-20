/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// EntryKey paired with a EntryValue.
public struct Entry: Equatable, Comparable {
    /// The entry key.
    public private(set) var key: EntryKey

    /// The entry value.
    public private(set) var value: EntryValue

    /// The entry metadata.
    public private(set) var metadata: EntryMetadata?

    /// Creates an Entry from the given key, value and metadata.
    /// - Parameters:
    ///   - key: the entry key.
    ///   - value: the entry value.
    ///   - entryMetadata: the entry metadata.
    public init(key: EntryKey, value: EntryValue, metadata: EntryMetadata?) {
        self.key = key
        self.value = value
        self.metadata = metadata
    }

    public static func < (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.key < rhs.key
    }
}

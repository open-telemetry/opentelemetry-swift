/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A map from EntryKey to EntryValue and EntryMetadata that can be used to
/// label anything that is associated with a specific operation.
/// For example, Baggages can be used to label stats, log messages, or
/// debugging information.
public protocol Baggage: AnyObject {
    /// Builder for the Baggage class
    static func baggageBuilder() -> BaggageBuilder

    /// Returns an immutable collection of the entries in this Baggage. Order of
    /// entries is not guaranteed.
    func getEntries() -> [Entry]

    ///  Returns the EntryValue associated with the given EntryKey.
    /// - Parameter key: entry key to return the value for.
    func getEntryValue(key: EntryKey) -> EntryValue?
}

public func == (lhs: Baggage, rhs: Baggage) -> Bool {
    guard type(of: lhs) == type(of: rhs) else { return false }
    return lhs.getEntries().sorted() == rhs.getEntries().sorted()
}

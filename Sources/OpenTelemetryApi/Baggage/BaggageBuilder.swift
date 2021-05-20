/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Builder for the Baggage class
public protocol BaggageBuilder: AnyObject {
    ///  Sets the parent Baggage to use. If no parent is provided, the value of
    ///  BaggageManager.getCurrentContext() at build() time will be used
    ///  as parent, unless setNoParent() was called.
    ///  This must be used to create a Baggage when manual Context
    ///  propagation is used.
    ///  If called multiple times, only the last specified value will be used.
    /// - Parameter parent: the Baggage used as parent
    @discardableResult func setParent(_ parent: Baggage?) -> Self

    /// Sets the option to become a root Baggage with no parent. If not
    /// called, the value provided using setParent(Baggage) or otherwise
    /// BaggageManager.getCurrentContext()} at build() time will be used as
    /// parent.
    @discardableResult func setNoParent() -> Self

    /// Adds the key/value pair and metadata regardless of whether the key is present.
    /// - Parameters:
    ///   - key: the EntryKey which will be set.
    ///   - value: the EntryValue to set for the given key.
    ///   - metadata: the EntryMetadata associated with this Entry.
    @discardableResult func put(key: EntryKey, value: EntryValue, metadata: EntryMetadata?) -> Self

    /// Removes the key if it exists.
    /// - Parameter key: the EntryKey which will be removed.
    @discardableResult func remove(key: EntryKey) -> Self

    /// Creates a Baggage from this builder. 
    func build() -> Baggage
}

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

extension BaggageBuilder {
    /// Builds and starts a span,  setting it as active for the duration of the closure. The span is ended when when the closure exits (even if an error is thrown).
    ///
    /// This ignores `setActive`.
    @discardableResult
    func withActive<T>(_ action: (Baggage) throws -> T) rethrows -> T {
        let baggage = self.build()

        return try OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage, { try action(baggage) })
    }

    /// Makes `self` the active span for the duration of the closure, ending the span when the closure exits (even if an error is thrown)
    ///
    /// This ignores `setActive`.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    func withActive<T>(_ action: (Baggage) async throws -> T) async rethrows -> T {
        let baggage = self.build()

        return try await OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage, { try await action(baggage) })
    }
}

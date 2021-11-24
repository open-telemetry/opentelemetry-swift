/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Carries tracing-system specific context in a list of key-value pairs. TraceState allows different
/// vendors propagate additional information and inter-operate with their legacy Id formats.
/// Implementation is optimized for a small list of key-value pairs.
/// Key is opaque string up to 256 characters printable. It MUST begin with a lowercase letter,
/// and can only contain lowercase letters a-z, digits 0-9, underscores _, dashes -, asterisks *, and
/// forward slashes /.
/// Value is opaque string up to 256 characters printable ASCII RFC0020 characters (i.e., the
/// range 0x20 to 0x7E) except comma , and =.
public struct TraceState: Equatable, Codable {
    private static let maxKeyValuePairs = 32

    public private(set) var entries = [Entry]()

    /// Returns the default with no entries.
    public init() {}

    public init?(entries: [Entry]) {
        guard entries.count <= TraceState.maxKeyValuePairs else { return nil }

        self.entries = entries
    }

    /// Returns the value to which the specified key is mapped, or nil if this map contains no mapping
    ///  for the key
    /// - Parameter key: key with which the specified value is to be associated
    public func get(key: String) -> String? {
        return entries.first(where: { $0.key == key })?.value
    }

    /// Adds or updates the Entry that has the given key if it is present. The new Entry will always
    /// be added in the front of the list of entries.
    /// - Parameters:
    ///   - key: the key for the Entry to be added.
    ///   - value: the value for the Entry to be added.
    internal mutating func set(key: String, value: String) {
        // Initially create the Entry to validate input.
        guard let entry = Entry(key: key, value: value) else { return }
        if entries.contains(where: { $0.key == entry.key }) {
            remove(key: entry.key)
        }
        entries.append(entry)
    }

    /// Returns a copy the traceState by appending the Entry that has the given key if it is present.
    /// The new Entry will always be added in the front of the existing list of entries.
    /// - Parameters:
    ///   - key: the key for the Entry to be added.
    ///   - value: the value for the Entry to be added.
    public func setting(key: String, value: String) -> Self {
        // Initially create the Entry to validate input.
        var newTraceState = self
        newTraceState.set(key: key, value: value)
        return newTraceState
    }

    /// Removes the Entry that has the given key if it is present.
    /// - Parameter key: the key for the Entry to be removed.
    internal mutating func remove(key: String) {
        if let index = entries.firstIndex(where: { $0.key == key }) {
            entries.remove(at: index)
        }
    }

    /// Returns a copy the traceState by removinf the Entry that has the given key if it is present.
    /// - Parameter key: the key for the Entry to be removed.
    public func removing(key: String) -> TraceState {
        // Initially create the Entry to validate input.
        var newTraceState = self
        newTraceState.remove(key: key)
        return newTraceState
    }

    /// Immutable key-value pair for TraceState
    public struct Entry: Equatable, Codable {
        /// The key of the Entry
        public private(set) var key: String

        /// The value of the Entry
        public private(set) var value: String

        /// Creates a new Entry for the TraceState.
        /// - Parameters:
        ///   - key: the Entry's key.
        ///   - value: the Entry's value.
        public init?(key: String, value: String) {
            if TraceStateUtils.validateKey(key: key), TraceStateUtils.validateValue(value: value) {
                self.key = key
                self.value = value
                return
            }
            return nil
        }
    }
}

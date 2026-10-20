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
public struct TraceState: Equatable, Codable, Sendable {
  private static let maxKeyValuePairs = 32

  public let entries: [Entry]

  /// Returns the default with no entries.
  public init() {
    self.entries = []
  }

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

  /// Returns a copy the traceState by appending the Entry that has the given key if it is present.
  /// The new Entry will always be added in the front of the existing list of entries.
  /// - Parameters:
  ///   - key: the key for the Entry to be added.
  ///   - value: the value for the Entry to be added.
  public func setting(key: String, value: String) -> Self {
    // Initially create the Entry to validate input.
    guard let entry = Entry(key: key, value: value) else { return self }
    var newEntries = entries
    TraceState.remove(key: key, from: &newEntries)
    newEntries.append(entry)
    return TraceState(entries: newEntries) ?? self
  }

  /// Removes the Entry that has the given key if it is present.
  /// - Parameters:
  ///   - key: the key for the Entry to be removed.
  ///   - entries: The entries array to modify.
  static private func remove(key: String, from entries: inout [Entry]) {
    if let index = entries.firstIndex(where: { $0.key == key }) {
      entries.remove(at: index)
    }
  }

  /// Returns a copy the traceState by removing the Entry that has the given key if it is present.
  /// - Parameter key: the key for the Entry to be removed.
  public func removing(key: String) -> TraceState {
    // Initially create the Entry to validate input.
    var newEntries = entries
    TraceState.remove(key: key, from: &newEntries)
    return TraceState(entries: newEntries) ?? self
  }

  /// Immutable key-value pair for TraceState
  public struct Entry: Equatable, Codable, Sendable {
    /// The key of the Entry
    public let key: String

    /// The value of the Entry
    public let value: String

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

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A key to a value stored in a Baggage.
/// Each EntryKey has a String name. Names have a maximum length of 255
/// and contain only printable ASCII characters.
/// EntryKeys are designed to be used as constants. Declaring each key as a constant
/// prevents key names from being validated multiple times.
public struct EntryKey: Equatable, Comparable, Hashable {
    /// The maximum length for an entry key name. The value is 255.
    static let maxLength = 255

    /// The name of the key
    public private(set) var name: String = ""

    /// Constructs an EntryKey with the given name.
    /// The name must meet the following requirements:
    /// - It cannot be longer than maxLength.
    /// - It can only contain printable ASCII characters.
    /// - Parameter name: the name of the key.
    public init?(name: String) {
        let name = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !EntryKey.isValid(name: name) {
            return nil
        }
        self.name = name
    }

    /// Determines whether the given String is a valid entry key.
    /// - Parameter value: the entry key name to be validated.
    private static func isValid(name: String) -> Bool {
        return name.count > 0 && name.count <= maxLength && StringUtils.isPrintableString(name)
    }

    public static func < (lhs: EntryKey, rhs: EntryKey) -> Bool {
        return lhs.name < rhs.name
    }
}

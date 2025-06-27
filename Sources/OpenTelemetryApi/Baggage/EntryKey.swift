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
  // RFC7230 token characters for valid keys
  private static let validKeyCharacters: CharacterSet = {
    var chars = CharacterSet()
    // tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
    chars.insert(charactersIn: "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return chars
  }()

  /// The maximum length for an entry key name. The value is 255.
  static let maxLength = 255

  /// The name of the key
  public private(set) var name: String = ""

  /// Constructs an EntryKey with the given name.
  /// The name must meet the following requirements:
  /// - It cannot be longer than maxLength.
  /// - It can only contain RFC7230 token characters:
  ///   - Letters (a-z, A-Z)
  ///   - Numbers (0-9)
  ///   - Special characters: ! # $ % & ' * + - . ^ _ ` | ~
  /// - Leading and trailing whitespace is trimmed
  /// - Parameter name: the name of the key.
  public init?(name: String) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !EntryKey.isValid(name: name) {
      return nil
    }
    self.name = name
  }

  private static func isValid(name: String) -> Bool {
    guard name.count > 0, name.count <= maxLength else {
      return false
    }

    // Validate against RFC7230 token rules
    return name.unicodeScalars.allSatisfy { validKeyCharacters.contains($0) }
  }

  public static func < (lhs: EntryKey, rhs: EntryKey) -> Bool {
    return lhs.name < rhs.name
  }
}

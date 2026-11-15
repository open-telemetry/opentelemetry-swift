/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A validated entry value.
/// Validation ensures that the String has a maximum length of 255 and
/// contains only printable ASCII characters.
public struct EntryValue: Equatable, Sendable {
  /// The maximum length for a entry value. The value is 255.
  static let maxLength = 255

  /// The entry value as String
  public private(set) var string: String = ""

  /// Constructs an EntryValue from the given string. The string must meet the following
  /// requirements:
  ///  - It cannot be longer than {255.
  ///  - It can only contain printable ASCII characters.
  public init?(string: String) {
    let string = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    if !EntryValue.isValid(value: string) {
      return nil
    }
    self.string = string
  }

  /// Determines whether the given String is a valid entry value.
  /// - Parameter value: value the entry value to be validated.
  private static func isValid(value: String) -> Bool {
    return value.count <= maxLength
  }
}

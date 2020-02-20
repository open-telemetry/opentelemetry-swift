// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/// A key to a value stored in a CorrelationContext.
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

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

/// A validated entry value.
/// Validation ensures that the String has a maximum length of 255 and
/// contains only printable ASCII characters.
public struct EntryValue: Equatable {
    /// The maximum length for a entry value. The value is 255.
    static let maxLength = 255

    /// The entry value as String
    public private(set) var string: String = ""

    /// Constructs an EntryValue from the given string. The string must meet the following
    /// requirements:
    ///  - It cannot be longer than {255.
    ///  - It can only contain printable ASCII characters.
    public init?(string: String) {
        if !EntryValue.isValid(value: string) {
            return nil
        }
        self.string = string
    }

    /// Determines whether the given String is a valid entry value.
    /// - Parameter value: value the entry value to be validated.
    private static func isValid(value: String) -> Bool {
        return value.count <= maxLength && StringUtils.isPrintableString(value)
    }
}

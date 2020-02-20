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

/// Internal utility methods for working with attribute keys, attribute values, and metric names
public struct StringUtils {
    /// Determines whether the String contains only printable characters.
    /// - Parameter string: the String to be validated.
    public static func isPrintableString(_ string: String) -> Bool {
        for char in string.unicodeScalars {
            if !isPrintableChar(char) {
                return false
            }
        }
        return true
    }

    private static func isPrintableChar(_ char: Unicode.Scalar) -> Bool {
        return char >= UnicodeScalar(" ") && char <= UnicodeScalar("~")
    }
}

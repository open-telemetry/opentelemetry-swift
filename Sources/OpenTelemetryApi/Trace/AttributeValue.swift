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

/// An enum that represents all the possible values for an attribute.
public enum AttributeValue: Equatable, CustomStringConvertible {
    case string(String?)
    case bool(Bool)
    case int(Int)
    case double(Double)

    public var description: String {
        switch self {
        case let .string(value):
            return value ?? ""
        case let .bool(value):
            return value ? "true" : "false"
        case let .int(value):
            return String(value)
        case let .double(value):
            return String(value)
        }
    }
}

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
import OpenTelemetryApi

/// Resource represents a resource, which capture identifying information about the entities
/// for which signals (stats or traces) are reported.
public struct Resource: Equatable {
    private static let maxLength = 255

    /// A dictionary of labels that describe the resource.
    public var labels: [String: String]

    ///  Returns an empty Resource.
    public init() {
        self.init(labels: [String: String]())
    }

    /// Returns a Resource.
    /// - Parameter labels: a dictionary of labels that describe the resource.
    public init(labels: [String: String]) {
        if Resource.checkLabels(labels: labels) {
            self.labels = labels
        } else {
            self.labels = [String: String]()
        }
    }

    /// Modifies the current Resource by merging with the other Resource.
    /// In case of a collision, current Resource takes precedence.
    /// - Parameter other: the Resource that will be merged with this
    public mutating func merge(other: Resource) {
        labels.merge(other.labels) { current, _ in current }
    }

    /// Returns a new, merged Resource by merging the current Resource with the other Resource.
    /// In case of a collision, current Resource takes precedence.
    /// - Parameter other: the Resource that will be merged with this
    public func merging(other: Resource) -> Resource {
        let labelsCopy = labels.merging(other.labels) { current, _ in current }
        return Resource(labels: labelsCopy)
    }

    private static func checkLabels(labels: [String: String]) -> Bool {
        for entry in labels {
            if !isValidAndNotEmpty(name: entry.key) || !isValid(name: entry.value) {
                return false
            }
        }
        return true
    }

    /// Determines whether the given String is a valid printable ASCII string with a length not
    /// exceed 255 characters.
    /// - Parameter name: the name to be validated.
    private static func isValid(name: String) -> Bool {
        return name.count <= maxLength && StringUtils.isPrintableString(name)
    }

    /// ¡Determines whether the given String is a valid printable ASCII string with a length
    /// greater than 0 and not exceed 255 characters.
    /// - Parameter name: the name to be validated.
    private static func isValidAndNotEmpty(name: String) -> Bool {
        return !name.isEmpty && isValid(name: name)
    }
}

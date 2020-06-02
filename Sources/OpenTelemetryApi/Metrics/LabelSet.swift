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

/// Normalized name value pairs of metric labels.
open class LabelSet: Hashable {
    public private(set) var labels: [String: String]

    /// Empty LabelSet.
    public static var empty = LabelSet()

    private init() {
        labels = [String: String]()
    }

    public required init(labels: [String: String]) {
        self.labels = labels
    }

    public static func == (lhs: LabelSet, rhs: LabelSet) -> Bool {
        return lhs.labels == rhs.labels
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(labels)
    }
}

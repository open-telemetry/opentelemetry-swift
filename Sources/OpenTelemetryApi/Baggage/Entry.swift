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

/// EntryKey paired with a EntryValue.
public struct Entry: Equatable, Comparable {
    /// The entry key.
    public private(set) var key: EntryKey

    /// The entry value.
    public private(set) var value: EntryValue

    /// The entry metadata.
    public private(set) var metadata: EntryMetadata

    /// Creates an Entry from the given key, value and metadata.
    /// - Parameters:
    ///   - key: the entry key.
    ///   - value: the entry value.
    ///   - entryMetadata: the entry metadata.
    public init(key: EntryKey, value: EntryValue, entryMetadata: EntryMetadata) {
        self.key = key
        self.value = value
        metadata = entryMetadata
    }

    public static func < (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.key < rhs.key
    }
}

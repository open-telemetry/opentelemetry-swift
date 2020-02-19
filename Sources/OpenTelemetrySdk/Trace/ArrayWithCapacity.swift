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

/// An array-like struct that has a maximum capacity,
/// when it reaces a maximum it discards first inserted elements
public struct ArrayWithCapacity<T> {
    private(set) var array = [T]()
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public mutating func append(_ item: T) {
        array.append(item)
        if array.count > capacity {
            _ = array.removeFirst()
        }
    }
}

extension ArrayWithCapacity: MutableCollection {
    public var startIndex: Int { return array.startIndex }
    public var endIndex: Int { return array.endIndex }

    public subscript(_ index: Int) -> T {
        get { return array[index] }
        set { array[index] = newValue }
    }

    public func index(after i: Int) -> Int {
        return array.index(after: i)
    }
}

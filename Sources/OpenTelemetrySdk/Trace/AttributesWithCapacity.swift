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

// A dixtionary implementation with a fixed capacity that drops events when the dictionary gets full. Eviction
// is based on the access order.
public struct AttributesWithCapacity {
    var dictionary: [String: AttributeValue]
    var keys: [String]
    private var capacity: Int
    private var recordedAttributes: Int

    init(capacity: Int) {
        dictionary = [String: AttributeValue]()
        keys = [String]()
        recordedAttributes = 0
        self.capacity = capacity
    }

    subscript(key: String) -> AttributeValue? {
        get {
            dictionary[key]
        }
        set {
            if newValue == nil {
                removeValueForKey(key: key)
            } else {
                _ = updateValue(value: newValue!, forKey: key)
            }
        }
    }

    @discardableResult mutating func updateValue(value: AttributeValue, forKey key: String) -> AttributeValue? {
        let oldValue = dictionary.updateValue(value, forKey: key)
        if oldValue == nil {
            recordedAttributes += 1
            keys.append(key)
        } else {
            keys.remove(at: keys.firstIndex(of: key)!)
            keys.append(key)
        }
        if dictionary.count > capacity {
            let key = keys.removeFirst()
            dictionary[key] = nil
        }
        return oldValue
    }

    mutating func updateValues(attributes: [String: AttributeValue]) {
        _ = attributes.keys.map {
            updateValue(value: attributes[$0]!, forKey: $0)
        }
    }

    mutating func updateValues(attributes: AttributesWithCapacity) {
        _ = attributes.keys.map {
            updateValue(value: attributes[$0]!, forKey: $0)
        }
    }

    mutating func removeValueForKey(key: String) {
        keys = keys.filter {
            $0 != key
        }
        dictionary.removeValue(forKey: key)
    }

    mutating func removeAll(keepCapacity: Int) {
        keys = []
        dictionary = Dictionary<String, AttributeValue>(minimumCapacity: keepCapacity)
    }

    var count: Int {
        dictionary.count
    }

    var numberOfDroppedAttributes: Int {
        recordedAttributes - dictionary.count
    }

    var values: Array<AttributeValue> {
        keys.map { dictionary[$0]! }
    }

    static func == (lhs: AttributesWithCapacity, rhs: AttributesWithCapacity) -> Bool {
        lhs.keys == rhs.keys && lhs.dictionary == rhs.dictionary
    }

    static func != (lhs: AttributesWithCapacity, rhs: AttributesWithCapacity) -> Bool {
        lhs.keys != rhs.keys || lhs.dictionary != rhs.dictionary
    }
}

extension AttributesWithCapacity: Sequence {
    public func makeIterator() -> AttributesWithCapacityIterator {
        AttributesWithCapacityIterator(sequence: dictionary, keys: keys, current: 0)
    }
}

public struct AttributesWithCapacityIterator: IteratorProtocol {
    let sequence: Dictionary<String, AttributeValue>
    let keys: Array<String>
    var current = 0

    public mutating func next() -> (String, AttributeValue)? {
        defer { current += 1 }
        guard sequence.count > current else {
            return nil
        }

        let key = keys[current]
        guard let value = sequence[key] else {
            return nil
        }
        return (key, value)
    }
}

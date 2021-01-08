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

// A dictionary implementation with a fixed capacity that drops events when the dictionary gets full. Eviction
// is based on the access order.
public struct AttributesDictionary {
    var attributes: [String: AttributeValue]
    var keys: [String]
    private var capacity: Int
    private var recordedAttributes: Int

    public init(capacity: Int) {
        attributes = [String: AttributeValue]()
        keys = [String]()
        recordedAttributes = 0
        self.capacity = capacity
    }

    public subscript(key: String) -> AttributeValue? {
        get {
            attributes[key]
        }
        set {
            if newValue == nil {
                removeValueForKey(key: key)
            } else {
                _ = updateValue(value: newValue!, forKey: key)
            }
        }
    }

    @discardableResult public mutating func updateValue(value: AttributeValue, forKey key: String) -> AttributeValue? {
        let oldValue = attributes.updateValue(value, forKey: key)
        if oldValue == nil {
            recordedAttributes += 1
            keys.append(key)
        } else {
            keys.remove(at: keys.firstIndex(of: key)!)
            keys.append(key)
        }
        if attributes.count > capacity {
            let key = keys.removeFirst()
            attributes[key] = nil
        }
        return oldValue
    }

    public mutating func updateValues(attributes: [String: AttributeValue]) {
        _ = attributes.keys.map {
            updateValue(value: attributes[$0]!, forKey: $0)
        }
    }

    public mutating func updateValues(attributes: AttributesDictionary) {
        _ = attributes.keys.map {
            updateValue(value: attributes[$0]!, forKey: $0)
        }
    }

    public mutating func removeValueForKey(key: String) {
        keys = keys.filter {
            $0 != key
        }
        attributes.removeValue(forKey: key)
    }

    public mutating func removeAll(keepCapacity: Int) {
        keys = []
        attributes = [String: AttributeValue](minimumCapacity: keepCapacity)
    }

    public var count: Int {
        attributes.count
    }

    public var numberOfDroppedAttributes: Int {
        recordedAttributes - attributes.count
    }

    public var values: [AttributeValue] {
        keys.map { attributes[$0]! }
    }

    static func == (lhs: AttributesDictionary, rhs: AttributesDictionary) -> Bool {
        lhs.keys == rhs.keys && lhs.attributes == rhs.attributes
    }

    static func != (lhs: AttributesDictionary, rhs: AttributesDictionary) -> Bool {
        lhs.keys != rhs.keys || lhs.attributes != rhs.attributes
    }
}

extension AttributesDictionary: Sequence {
    public func makeIterator() -> AttributesWithCapacityIterator {
        AttributesWithCapacityIterator(sequence: attributes, keys: keys, current: 0)
    }
}

public struct AttributesWithCapacityIterator: IteratorProtocol {
    let sequence: [String: AttributeValue]
    let keys: [String]
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

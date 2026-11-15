/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

// A dictionary implementation with a fixed capacity that drops events when the dictionary gets full. Eviction
// is based on the access order.
public struct AttributesDictionary {
  var attributes: [String: AttributeValue]
  var keys: [String]
  private var capacity: Int
  private var valueLengthLimit: Int
  private var recordedAttributes: Int

  public init(capacity: Int, valueLengthLimit: Int = Int.max) {
    attributes = [String: AttributeValue]()
    keys = [String]()
    recordedAttributes = 0
    self.valueLengthLimit = valueLengthLimit
    self.capacity = capacity
  }

  public subscript(key: String) -> AttributeValue? {
    get {
      attributes[key]
    }
    set {
      if newValue == nil {
        _ = removeValueForKey(key: key)
      } else {
        _ = updateValue(value: newValue!, forKey: key)
      }
    }
  }

  @discardableResult public mutating func updateValue(value: AttributeValue, forKey key: String) -> AttributeValue? {
    var attributedValue = value
    switch value {
    case let .string(v):
      if v.count > valueLengthLimit {
        attributedValue = AttributeValue.string(
          String(v.prefix(valueLengthLimit)))
      }
    case let .array(v):
      var array = [AttributeValue]()
      v.values.forEach { value in
        switch value {
        case let .string(value):
          array.append(
            AttributeValue.string(String(value.prefix(valueLengthLimit))))
        default:
          array.append(value)
        }
        attributedValue = AttributeValue.array(AttributeArray(values: array))
      }
    default:
      break
    }
    let oldValue = attributes.updateValue(attributedValue, forKey: key)
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

  public mutating func removeValueForKey(key: String) -> AttributeValue? {
    keys = keys.filter {
      $0 != key
    }
    return attributes.removeValue(forKey: key)
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

extension AttributesDictionary {
  public func attributesCopy() -> [String: AttributeValue] {
    Dictionary(uniqueKeysWithValues: attributes.map { ($0.key, $0.value) })
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

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An enum that represents all the possible values for an attribute.
public enum AttributeValue: Equatable, CustomStringConvertible, Hashable {
  case string(String)
  case bool(Bool)
  case int(Int)
  case double(Double)
  case stringArray([String])
  case boolArray([Bool])
  case intArray([Int])
  case doubleArray([Double])
  case set(AttributeSet)

  public var description: String {
    switch self {
    case let .string(value):
      return value
    case let .bool(value):
      return value ? "true" : "false"
    case let .int(value):
      return String(value)
    case let .double(value):
      return String(value)
    case let .stringArray(value):
      return value.description
    case let .boolArray(value):
      return value.description
    case let .intArray(value):
      return value.description
    case let .doubleArray(value):
      return value.description
    case let .set(value):
      return value.labels.description
    }
  }

  public init?(_ value: Any) {
    switch value {
    case let val as String:
      self = .string(val)
    case let val as Bool:
      self = .bool(val)
    case let val as Int:
      self = .int(val)
    case let val as Double:
      self = .double(val)
    case let val as [String]:
      self = .stringArray(val)
    case let val as [Bool]:
      self = .boolArray(val)
    case let val as [Int]:
      self = .intArray(val)
    case let val as [Double]:
      self = .doubleArray(val)
    case let val as AttributeSet:
      self = .set(val)
    default:
      return nil
    }
  }
}

extension AttributeValue {
  public init(_ value: String) {
    self = .string(value)
  }

  public init(_ value: Bool) {
    self = .bool(value)
  }

  public init(_ value: Int) {
    self = .int(value)
  }

  public init(_ value: Double) {
    self = .double(value)
  }

  public init(_ value: [String]) {
    self = .stringArray(value)
  }

  public init(_ value: [Int]) {
    self = .intArray(value)
  }

  public init(_ value: [Double]) {
    self = .doubleArray(value)
  }

  public init(_ value: AttributeSet) {
    self = .set(value)
  }
}

internal struct AttributeValueExplicitCodable: Codable {
  let attributeValue: AttributeValue

  enum CodingKeys: String, CodingKey {
    case string
    case bool
    case int
    case double
    case stringArray
    case boolArray
    case intArray
    case doubleArray
    case set
  }

  enum AssociatedValueCodingKeys: String, CodingKey {
    case associatedValue = "_0"
  }

  internal init(attributeValue: AttributeValue) {
    self.attributeValue = attributeValue
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.allKeys.count == 1 else {
      let context = DecodingError.Context(
        codingPath: container.codingPath,
        debugDescription: "Invalid number of keys found, expected one.")
      throw DecodingError.typeMismatch(Status.self, context)
    }

    switch container.allKeys.first.unsafelyUnwrapped {
    case .string:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .string)
      self.attributeValue = .string(
        try nestedContainer.decode(String.self, forKey: .associatedValue))
    case .bool:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .bool)
      self.attributeValue = .bool(try nestedContainer.decode(Bool.self, forKey: .associatedValue))
    case .int:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .int)
      self.attributeValue = .int(try nestedContainer.decode(Int.self, forKey: .associatedValue))
    case .double:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .double)
      self.attributeValue = .double(
        try nestedContainer.decode(Double.self, forKey: .associatedValue))
    case .stringArray:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .stringArray)
      self.attributeValue = .stringArray(
        try nestedContainer.decode([String].self, forKey: .associatedValue))
    case .boolArray:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .boolArray)
      self.attributeValue = .boolArray(
        try nestedContainer.decode([Bool].self, forKey: .associatedValue))
    case .intArray:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .intArray)
      self.attributeValue = .intArray(
        try nestedContainer.decode([Int].self, forKey: .associatedValue))
    case .doubleArray:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .doubleArray)
      self.attributeValue = .doubleArray(
        try nestedContainer.decode([Double].self, forKey: .associatedValue))
    case .set:
      let nestedContainer = try container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .set)
      self.attributeValue = .set(
        try nestedContainer.decode(AttributeSet.self, forKey: .associatedValue))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self.attributeValue {
    case let .string(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .string)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .bool(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .bool)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .int(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .int)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .double(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .double)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .stringArray(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .stringArray)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .boolArray(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .boolArray)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .intArray(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .intArray)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .doubleArray(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .doubleArray)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .set(value):
      var nestedContainer = container.nestedContainer(
        keyedBy: AssociatedValueCodingKeys.self, forKey: .set)
      try nestedContainer.encode(value, forKey: .associatedValue)
    }
  }
}

#if swift(>=5.5)
  // swift 5.5 supports synthesizing Codable for enums with associated values
  // see https://github.com/apple/swift-evolution/blob/main/proposals/0295-codable-synthesis-for-enums-with-associated-values.md
  extension AttributeValue: Codable {}
#else
  // for older swift versions use a forward compatible explicit Codable implementation
  extension AttributeValue: Codable {
    public init(from decoder: Decoder) throws {
      let explicitDecoded = try AttributeValueExplicitCodable(from: decoder)

      self = explicitDecoded.attributeValue
    }

    public func encode(to encoder: Encoder) throws {
      let explicitEncoded = AttributeValueExplicitCodable(attributeValue: self)

      try explicitEncoded.encode(to: encoder)
    }
  }
#endif

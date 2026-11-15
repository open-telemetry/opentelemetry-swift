/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An enum that represents all the possible values for an attribute.
public enum AttributeValue: Equatable, CustomStringConvertible, Hashable, Sendable {
  case string(String)
  case bool(Bool)
  case int(Int)
  case double(Double)
  @available(*, deprecated, message: "replaced by .array(AttributeArray)") case stringArray([String])
  @available(*, deprecated, message: "replaced by .array(AttributeArray)") case boolArray([Bool])
  @available(*, deprecated, message: "replaced by .array(AttributeArray)") case intArray([Int])
  @available(*, deprecated, message: "replaced by .array(AttributeArray)") case doubleArray([Double])
  case array(AttributeArray)
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
    case let .array(value):
      return value.description
    case let .set(value):
      return value.labels.description
    }
  }

  // swiftlint:disable cyclomatic_complexity
  public init?(_ value: Any) {
    switch value {
    case is String:
      // swiftlint:disable force_cast
      self = .string(value as! String)
    // swiftlint:enable force_cast
    case let val as Bool:
      self = .bool(val)
    case let val as Int:
      self = .int(val)
    case let val as Double:
      self = .double(val)
    case let val as [String]:
      self = .array(AttributeArray(values: val.map { AttributeValue.string($0) }))
    case let val as [Bool]:
      self = .array(AttributeArray(values: val.map { AttributeValue.bool($0) }))
    case let val as [Int]:
      self = .array(AttributeArray(values: val.map { AttributeValue.int($0) }))
    case let val as [Double]:
      self = .array(AttributeArray(values: val.map { AttributeValue.double($0) }))
    case let val as AttributeArray:
      self = .array(val)
    case let val as AttributeSet:
      self = .set(val)
    default:
      return nil
    }
  }
  // swiftlint:enable cyclomatic_complexity
}

public extension AttributeValue {
  init(_ value: String) {
    self = .string(value)
  }

  init(_ value: Bool) {
    self = .bool(value)
  }

  init(_ value: Int) {
    self = .int(value)
  }

  init(_ value: Double) {
    self = .double(value)
  }

  init(_ value: [String]) {
    self = .array(AttributeArray(values: value.map { element in
      return AttributeValue.string(element)
    }))
  }

  init(_ value: [Int]) {
    self = .array(AttributeArray(values: value.map { element in
      return AttributeValue.int(element)
    }))
  }

  init(_ value: [Double]) {
    self = .array(AttributeArray(values: value.map { element in
      return AttributeValue.double(element)
    }))
  }

  init(_ value: [Bool]) {
    self = .array(AttributeArray(values: value.map { element in
      return AttributeValue.bool(element)
    }))
  }

  init(_ value: AttributeArray) {
    self = .array(value)
  }

  init(_ value: AttributeSet) {
    self = .set(value)
  }
}

struct AttributeValueExplicitCodable: Codable {
  let attributeValue: AttributeValue

  enum CodingKeys: String, CodingKey {
    case string
    case bool
    case int
    case double
    case array
    case set
  }

  enum AssociatedValueCodingKeys: String, CodingKey {
    case associatedValue = "_0"
  }

  init(attributeValue: AttributeValue) {
    self.attributeValue = attributeValue
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.allKeys.count == 1 else {
      let context = DecodingError.Context(codingPath: container.codingPath,
                                          debugDescription: "Invalid number of keys found, expected one.")
      throw DecodingError.typeMismatch(Status.self, context)
    }

    switch container.allKeys.first.unsafelyUnwrapped {
    case .string:
      let nestedContainer = try container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .string)
      attributeValue = try .string(
        nestedContainer.decode(String.self, forKey: .associatedValue))
    case .bool:
      let nestedContainer = try container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .bool)
      attributeValue = try .bool(nestedContainer.decode(Bool.self, forKey: .associatedValue))
    case .int:
      let nestedContainer = try container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .int)
      attributeValue = try .int(nestedContainer.decode(Int.self, forKey: .associatedValue))
    case .double:
      let nestedContainer = try container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .double)
      attributeValue = try .double(
        nestedContainer.decode(Double.self, forKey: .associatedValue))
    case .array:
      let nestedContainer = try container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .array)
      attributeValue = try .array(nestedContainer.decode(AttributeArray.self, forKey: .associatedValue))
    case .set:
      let nestedContainer = try container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .set)
      attributeValue = try .set(
        nestedContainer.decode(AttributeSet.self, forKey: .associatedValue))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch attributeValue {
    case let .string(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .string)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .bool(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .bool)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .int(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .int)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .double(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .double)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .set(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .set)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .array(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .array)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .stringArray(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .array)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .boolArray(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .array)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .intArray(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .array)
      try nestedContainer.encode(value, forKey: .associatedValue)
    case let .doubleArray(value):
      var nestedContainer = container.nestedContainer(keyedBy: AssociatedValueCodingKeys.self, forKey: .array)
      try nestedContainer.encode(value, forKey: .associatedValue)
    }
  }
}

extension AttributeValue: Codable {}

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Resource represents a resource, which capture identifying information about the entities
/// for which signals (stats or traces) are reported.
public struct Resource: Equatable, Hashable, Codable {
  private static let maxLength = 255

  /// A dictionary of labels that describe the resource.
  public var attributes: [String: AttributeValue]

  public private(set) var entities : [Entity] = []

  ///  Returns a default Resource.
  public init() {
    let executableName = ProcessInfo.processInfo.processName
    self.init(attributes: [
      ResourceAttributes.serviceName.rawValue: AttributeValue.string(
        "unknown_service:\(executableName)"),
      ResourceAttributes.telemetrySdkName.rawValue: AttributeValue.string(
        "opentelemetry"),
      ResourceAttributes.telemetrySdkLanguage.rawValue: AttributeValue.string(
        "swift"),
      ResourceAttributes.telemetrySdkVersion.rawValue: AttributeValue.string(
        Resource.OTEL_SWIFT_SDK_VERSION)
    ]
    )
  }

  public func builder() -> ResourceBuilder {
    return ResourceBuilder()
      .add(attributes: self.attributes)
  }

  public static func builder() -> ResourceBuilder {
    return ResourceBuilder()
  }

  private static func mergeEntities(_ lhs: [Entity], _ rhs: [Entity]) -> [Entity] {
    if lhs.isEmpty {
      return rhs
    }

    if rhs.isEmpty {
      return lhs
    }
    var entityMap = [String: Entity]()
    lhs.forEach { entityMap[$0.type] = $0 }
    rhs.forEach { entity in
      if !entityMap.contains(where: { key, _ in
        entity.type == key
      }) {
        entityMap[entity.type] = entity
      } else {
        if let old = entityMap[entity.type] {
          let new = Entity.builder(type: old.type)
            .with(identifiersKeys: Array(entity.identifierKeys.union(old.identifierKeys)))
            .with(attributeKeys: Array(entity.attributeKeys.union(old.attributeKeys)))
            .build()
          entityMap[entity.type] = new
        }
      }
    }
    return Array(entityMap.values)
  }

  ///  Returns an empty Resource.
  static var empty: Resource {
    return self.init(attributes: [String: AttributeValue]())
  }

  /// Returns a Resource.
  /// - Parameter labels: a dictionary of labels that describe the resource.
  public init(attributes: [String: AttributeValue], entities: [Entity] = []) {
    self.entities = entities
    if Resource.checkAttributes(attributes: attributes) {
      self.attributes = attributes
    } else {
      self.attributes = [String: AttributeValue]()
    }

  }

  /// Modifies the current Resource by merging with the other Resource.
  /// In case of a collision, new Resource takes precedence.
  /// - Parameter other: the Resource that will be merged with this
  public mutating func merge(other: Resource) {
    attributes.merge(other.attributes) { _, other in other }
    entities = Resource.mergeEntities(entities, other.entities)
  }

  /// Returns a new, merged Resource by merging the current Resource with the other Resource.
  /// In case of a collision, new Resource takes precedence.
  /// - Parameter other: the Resource that will be merged with this
  public func merging(other: Resource) -> Resource {
    let labelsCopy = attributes.merging(other.attributes) { _, other in other }
    let entities = Resource.mergeEntities(self.entities, other.entities)
    return Resource(attributes: labelsCopy, entities: entities)
  }

  internal static func checkAttributes(attributes: [String: AttributeValue]) -> Bool {
    for entry in attributes where !isValidAndNotEmpty(name: entry.key) {
      return false
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

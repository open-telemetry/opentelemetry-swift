//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import OpenTelemetryApi

public struct Entity : Codable, Hashable, Equatable {
  /// type : Defines the type of the Entity. MUST not change during the lifetime of the entity.
  /// For example: "service" or "host". This field is required and MUST not be empty for valid entities.
  public let type: String

  /// id: A set of attributes that identifies the Entity.
  /// MUST not change during the lifetime of the Entity. The Id must contain at least one attribute.
  public let identifiers: [String: AttributeValue]

  /// A set of descriptive (non-identifying) attributes of the Entity.
  /// MAY change over the lifetime of the entity. MAY be empty. These attributes are not part of Entity's identity.
  public var attributes: [String: AttributeValue]


  public static func builder(type: String) -> EntityBuilder {
    .init(type: type)
  }
}

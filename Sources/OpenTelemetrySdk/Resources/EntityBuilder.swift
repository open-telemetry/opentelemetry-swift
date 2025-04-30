//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import OpenTelemetryApi

public class EntityBuilder {
  private var type: String
  private var identifiers: [String: AttributeValue] = [:]
  private var attributes: [String: AttributeValue] = [:]

  internal init(type: String) {
    self.type = type
  }

  public func with(identifiers: [String: AttributeValue]) -> Self {
    self.identifiers = identifiers
    return self
  }

  public func with(attributes: [String: AttributeValue]) -> Self {
    self.attributes = attributes
    return self
  }

  public func build() -> Entity {
    return Entity(type: type,
                  identifiers: identifiers,
                  attributes: attributes)
  }
}

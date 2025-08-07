//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import OpenTelemetryApi

public class EntityBuilder {
  private var type: String
  private var identifierKeys: Set<String> = []
  private var attributeKeys: Set<String> = []

  internal init(type: String) {
    self.type = type
  }

  public func with(identifiersKeys: [String]) -> Self {
    self.identifierKeys = Set(identifiersKeys)
    return self
  }

  public func with(attributeKeys: [String]) -> Self {
    self.attributeKeys = Set(attributeKeys)
    return self
  }

  public func build() -> Entity {
    return Entity(type: type,
                  identifierKeys: identifierKeys,
                  attributeKeys: attributeKeys)
  }
}

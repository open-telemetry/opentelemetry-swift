//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import OpenTelemetryApi
#if canImport(os.log)
import os.log
#endif

public class ResourceBuilder {
  private var attributes: [String: AttributeValue] = [:]
  private var entities: [Entity] = []

  public func add(entityDetector: EntityDetector) -> Self {
    entities.append(contentsOf: entityDetector.detectEntities())
    return self
  }

  public func add(attributes: [String: AttributeValue]) -> Self {
    for element in attributes {
      _ = self.add(key: element.key, value: element.value)
    }
    return self
  }

  func add(key: String, value: AttributeValue) -> Self {
    if(!Resource.checkAttributes(attributes: [key: value])) {
#if canImport(os.log)
      os_log(
        .error,
        "Failed to add attribute %@: %@, invalid key.",
        key,
        value.description
      )
#endif
      return self
    }
    attributes[key] = value
    return self
  }

  public func build() -> Resource {
    Resource(attributes: self.attributes, entities: entities)
  }
}

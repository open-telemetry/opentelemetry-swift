/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public enum ResourceAdapter {
  public static func toProtoResource(resource: Resource) -> Opentelemetry_Proto_Resource_V1_Resource {
    var outputResource = Opentelemetry_Proto_Resource_V1_Resource()
    resource.attributes.forEach {
      let protoAttribute = CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value)
      outputResource.attributes.append(protoAttribute)
    }
    resource.entities.forEach {
      if $0.identifierKeys.isEmpty {
        return
      }
      var entityRef = Opentelemetry_Proto_Common_V1_EntityRef()
      entityRef.type = $0.type
      entityRef.idKeys = Array($0.identifierKeys)
      entityRef.descriptionKeys = Array($0.attributeKeys)
      outputResource.entityRefs.append(entityRef)
    }
    return outputResource
  }
}

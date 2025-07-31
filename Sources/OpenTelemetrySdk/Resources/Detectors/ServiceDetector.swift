//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

public struct ServiceDetector : EntityDetector {
  public init() {}
  public func detectEntities() -> [Entity] {
    return [Entity.builder(type: "service")
      .with(identifiersKeys: [
        ResourceAttributes.serviceName.rawValue,
      ])
      .with(attributeKeys: [
        ResourceAttributes.serviceVersion.rawValue,
        ResourceAttributes.serviceNamespace.rawValue,
      ])
      .build()]
  }
}

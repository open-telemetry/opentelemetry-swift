//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public struct TelemetrySdkDetector : EntityDetector {
  public init() {}
  public func detectEntities() -> [Entity] {
    return [Entity.builder(type: "telemetry.sdk")
      .with(identifiersKeys: [
        ResourceAttributes.telemetrySdkName.rawValue,
        ResourceAttributes.telemetrySdkLanguage.rawValue,
      ])
      .with(attributeKeys: [
        ResourceAttributes.telemetrySdkVersion.rawValue,
      ])
      .build()]
  }
}

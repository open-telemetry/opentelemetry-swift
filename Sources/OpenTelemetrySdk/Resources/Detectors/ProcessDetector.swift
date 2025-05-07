//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public struct ProcessDetector : EntityDetector {
  public init() {}
  public func detectEntities() -> [Entity] {
    return [Entity.builder(type: "process")
      .with(identifiersKeys: [
        ResourceAttributes.processExecutableName.rawValue,
      ])
        .with(attributeKeys: [
          ResourceAttributes.processExecutablePath.rawValue,
          ResourceAttributes.processPid.rawValue,
          ResourceAttributes.processOwner.rawValue,
          ResourceAttributes.processParentPid.rawValue,
          ResourceAttributes.processCommandArgs.rawValue,
          ResourceAttributes.processCommandLine.rawValue,

        ])
        .build()]
  }
}

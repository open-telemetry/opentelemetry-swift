/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class OSResourceProvider: ResourceProvider {
  let osDataSource: IOperatingSystemDataSource

  public init(source: IOperatingSystemDataSource) {
    osDataSource = source
  }

  override public var attributes: [String: AttributeValue] {
    var attributes = [String: AttributeValue]()

    attributes[SemanticConventions.Os.type.rawValue] = .string(osDataSource.type)
    attributes[SemanticConventions.Os.name.rawValue] = .string(osDataSource.name)
    attributes[SemanticConventions.Os.description.rawValue] = .string(osDataSource.description)
    attributes[SemanticConventions.Os.version.rawValue] = .string(osDataSource.version)

    return attributes
  }
}

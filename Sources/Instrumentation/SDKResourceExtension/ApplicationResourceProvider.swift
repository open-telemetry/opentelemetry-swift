/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class ApplicationResourceProvider: ResourceProvider {
  let applicationDataSource: IApplicationDataSource

  public init(source: IApplicationDataSource) {
    applicationDataSource = source
  }

  override public var attributes: [String: AttributeValue] {
    var attributes = [String: AttributeValue]()

    if let bundleName = applicationDataSource.name {
      attributes[SemanticConventions.Service.name.rawValue] = AttributeValue.string(bundleName)
    }

    if let version = applicationVersion() {
      attributes[SemanticConventions.Service.version.rawValue] = AttributeValue.string(version)
    }

    return attributes
  }

  func applicationVersion() -> String? {
    if let build = applicationDataSource.build {
      if let version = applicationDataSource.version {
        return "\(version) (\(build))"
      }
      return build
    } else {
      return applicationDataSource.version
    }
  }
}

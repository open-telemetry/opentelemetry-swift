/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class TelemetryResourceProvider: ResourceProvider {
  let telemetrySource: ITelemetryDataSource

  public init(source: ITelemetryDataSource) {
    telemetrySource = source
  }

  override public var attributes: [String: AttributeValue] {
    var attributes = [String: AttributeValue]()

    attributes[SemanticConventions.Telemetry.sdkName.rawValue] = AttributeValue.string(telemetrySource.name)

    attributes[SemanticConventions.Telemetry.sdkLanguage.rawValue] = AttributeValue.string(telemetrySource.language)

    if let frameworkVersion = telemetrySource.version {
      attributes[SemanticConventions.Telemetry.sdkVersion.rawValue] = AttributeValue.string(frameworkVersion)
    }

    return attributes
  }
}

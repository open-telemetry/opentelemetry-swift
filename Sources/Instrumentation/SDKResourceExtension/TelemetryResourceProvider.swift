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

        attributes[ResourceAttributes.telemetrySdkName.rawValue] = AttributeValue.string(telemetrySource.name)

        attributes[ResourceAttributes.telemetrySdkLanguage.rawValue] = AttributeValue.string(telemetrySource.language)

        if let frameworkVersion = telemetrySource.version {
            attributes[ResourceAttributes.telemetrySdkVersion.rawValue] = AttributeValue.string(frameworkVersion)
        }

        return attributes
    }
}

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

        attributes[ResourceAttributes.osType.rawValue] = AttributeValue.string(osDataSource.type)
        attributes[ResourceAttributes.osDescription.rawValue] = AttributeValue.string(osDataSource.description)

        return attributes
    }
}

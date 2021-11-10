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

        attributes[ResourceAttributes.osType.rawValue] = .string(osDataSource.type)
        attributes[ResourceAttributes.osName.rawValue] = .string(osDataSource.name)
        attributes[ResourceAttributes.osDescription.rawValue] = .string(osDataSource.description)
        attributes[ResourceAttributes.osVersion.rawValue] = .string(osDataSource.version)

        return attributes
    }
}

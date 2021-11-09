/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

import OpenTelemetryApi
import OpenTelemetrySdk

public class DeviceResourceProvider: ResourceProvider {
    let deviceSource: IDeviceDataSource

    public init(source: IDeviceDataSource) {
        deviceSource = source
    }

    override public var attributes: [String: AttributeValue] {
        var attributes = [String: AttributeValue]()

        if let deviceModel = deviceSource.model {
            attributes[ResourceAttributes.deviceModelIdentifier.rawValue] = AttributeValue.string(deviceModel)
        }

        if let deviceId = deviceSource.identifier {
            attributes[ResourceAttributes.deviceId.rawValue] = AttributeValue.string(deviceId)
        }

        return attributes
    }
}

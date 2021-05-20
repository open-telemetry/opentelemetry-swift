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
            // TODO: update with semantic convention when it is added to the OTel sdk.
            attributes["device.model"] = AttributeValue.string(deviceModel)
        }

        if let deviceId = deviceSource.identifier {
            attributes[ResourceAttributes.hostId.rawValue] = AttributeValue.string(deviceId)
        }

        return attributes
    }
}

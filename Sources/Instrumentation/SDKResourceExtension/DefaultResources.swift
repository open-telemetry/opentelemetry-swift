/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public class DefaultResources {
    // add new resource providers here
    let application = ApplicationResourceProvider(source: ApplicationDataSource())
    let device = DeviceResourceProvider(source: DeviceDataSource())
    let os = OSResourceProvider(source: OperatingSystemDataSource())

    let telemetry = TelemetryResourceProvider(source: TelemetryDataSource())

    public init() {}

    public func get() -> Resource {
        var resource = Resource()
        let mirror = Mirror(reflecting: self)
        for children in mirror.children {
            if let provider = children.value as? ResourceProvider {
                resource.merge(other: provider.create())
            }
        }
        return resource
    }
}
